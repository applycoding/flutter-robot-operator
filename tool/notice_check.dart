// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

/// Parses NOTICE entries of the form `name | version | SPDX`.
final class NoticeEntry {
  const NoticeEntry(this.name, this.version, this.license);

  final String name;
  final String version;
  final String license;

  @override
  String toString() => '$name | $version | $license';
}

void main(List<String> args) {
  final root = _repoRoot();
  final noticePath = File('${root.path}/NOTICE');
  if (!noticePath.existsSync()) {
    stderr.writeln('missing NOTICE');
    exit(1);
  }

  final listed = _parseNotice(noticePath.readAsStringSync());
  final required = <String, NoticeEntry>{};

  _collectPubWorkspaceDeps(root, required);
  _collectE2eDeps(root, required);
  _collectKnownToolchain(required);

  final listedByKey = {for (final e in listed) _key(e.name): e};

  var failed = false;
  for (final need in required.values) {
    final listedEntry = listedByKey[_key(need.name)];
    if (listedEntry == null) {
      stderr.writeln('NOTICE missing entry: $need');
      failed = true;
      continue;
    }
    if (listedEntry.version != need.version) {
      stderr.writeln(
        'NOTICE version mismatch for ${need.name}: have ${listedEntry.version}, need ${need.version}',
      );
      failed = true;
    }
  }
  for (final have in listed) {
    if (!required.containsKey(_key(have.name)) &&
        !_optionalListed(_key(have.name))) {
      stderr.writeln('NOTICE lists unused entry: $have');
      failed = true;
    }
  }

  if (failed) {
    exit(1);
  }
  stdout.writeln('NOTICE check passed (${listed.length} entries).');
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current;
    }
    dir = parent;
  }
  return dir;
}

bool _optionalListed(String key) => false;

String _key(String name) => name.trim().toLowerCase();

List<NoticeEntry> _parseNotice(String text) {
  final out = <NoticeEntry>[];
  for (final line in text.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) {
      continue;
    }
    final parts = t.split('|').map((s) => s.trim()).toList();
    if (parts.length != 3) {
      stderr.writeln('bad NOTICE line: $line');
      exit(1);
    }
    out.add(NoticeEntry(parts[0], parts[1], parts[2]));
  }
  return out;
}

void _collectKnownToolchain(Map<String, NoticeEntry> out) {
  out[_key('Flutter SDK')] = const NoticeEntry(
    'Flutter SDK',
    '3.47.9',
    'BSD-3-Clause',
  );
  out[_key('Dart SDK')] = const NoticeEntry(
    'Dart SDK',
    '3.13.7',
    'BSD-3-Clause',
  );
  out[_key('Node.js')] = const NoticeEntry('Node.js', '24.22.1', 'MIT');
  out[_key('Chromium (Playwright bundle)')] = const NoticeEntry(
    'Chromium (Playwright bundle)',
    'bundled with Playwright 1.65.0',
    'BSD-3-Clause and others (not redistributed)',
  );
}

void _collectPubWorkspaceDeps(Directory root, Map<String, NoticeEntry> out) {
  final lockText = File('${root.path}/pubspec.lock').readAsStringSync();
  final pubspecPaths = [
    'pubspec.yaml',
    'packages/robot_protocol/pubspec.yaml',
    'packages/robot_sim/pubspec.yaml',
    'packages/robot_server/pubspec.yaml',
    'apps/operator_app/pubspec.yaml',
  ];

  final direct = <String>{};
  for (final rel in pubspecPaths) {
    final f = File('${root.path}/$rel');
    if (!f.existsSync()) {
      continue;
    }
    final ps = _loadYamlMap(f.readAsStringSync());
    direct.addAll(_depNames(ps, 'dependencies'));
    direct.addAll(_depNames(ps, 'dev_dependencies'));
    direct.addAll(_depNames(ps, 'dependency_overrides'));
  }

  for (final name in direct) {
    if (name == 'flutter' ||
        name == 'flutter_test' ||
        name == 'robot_protocol' ||
        name == 'robot_sim' ||
        name == 'robot_server' ||
        name == 'operator_app' ||
        name == 'path') {
      continue;
    }
    final version = _lockVersion(lockText, name);
    if (version == null) {
      stderr.writeln('no lock entry for $name');
      exit(1);
    }
    out[_key(name)] = NoticeEntry(name, version, _defaultLicense(name));
  }
}

String? _lockVersion(String lockText, String name) {
  final re = RegExp(
    '^  $name:\\s*\n(?:    [^\n]+\n)*?    version: "([^"]+)"',
    multiLine: true,
  );
  final match = re.firstMatch(lockText);
  return match?.group(1);
}

Set<String> _depNames(Map<String, dynamic> pubspec, String section) {
  final deps = pubspec[section];
  if (deps is! Map) {
    return {};
  }
  final names = <String>{};
  for (final name in deps.keys) {
    if (name == 'sdk') {
      continue;
    }
    final spec = deps[name];
    if (spec is String && spec == 'flutter') {
      continue;
    }
    if (spec is Map && (spec.containsKey('path') || spec.containsKey('sdk'))) {
      continue;
    }
    names.add(name as String);
  }
  return names;
}

void _collectE2eDeps(Directory root, Map<String, NoticeEntry> out) {
  final lockPath = File('${root.path}/apps/operator_app/e2e/package-lock.json');
  if (!lockPath.existsSync()) {
    stderr.writeln('missing apps/operator_app/e2e/package-lock.json');
    exit(1);
  }
  final json = jsonDecode(lockPath.readAsStringSync()) as Map<String, dynamic>;
  final pkgPath = File('${root.path}/apps/operator_app/e2e/package.json');
  final pkg = jsonDecode(pkgPath.readAsStringSync()) as Map<String, dynamic>;
  final devDeps = pkg['devDependencies'] as Map<String, dynamic>? ?? {};
  for (final name in devDeps.keys) {
    final version = _npmLockVersion(json, name);
    out[_key(name)] = NoticeEntry(
      name,
      version,
      name == '@playwright/test' ? 'Apache-2.0' : 'MIT',
    );
  }
}

String _npmLockVersion(Map<String, dynamic> lock, String name) {
  final packages = lock['packages'] as Map<String, dynamic>? ?? {};
  for (final key in packages.keys) {
    if (key == 'node_modules/$name' || key.endsWith('/$name')) {
      final meta = packages[key] as Map<String, dynamic>;
      return '${meta['version']}';
    }
  }
  return devVersionFromRoot(lock, name);
}

String devVersionFromRoot(Map<String, dynamic> lock, String name) {
  final packages = lock['packages'] as Map<String, dynamic>? ?? {};
  final entry = packages['node_modules/$name'];
  if (entry is Map && entry['version'] != null) {
    return '${entry['version']}';
  }
  return '';
}

String _defaultLicense(String name) {
  return switch (name) {
    'lints' ||
    'flutter_lints' ||
    'test' ||
    'async' ||
    'web_socket_channel' ||
    'test_api' => 'BSD-3-Clause',
    _ => 'BSD-3-Clause',
  };
}

Map<String, dynamic> _loadYamlMap(String text) {
  final map = <String, dynamic>{};
  String? section;
  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (!line.startsWith(' ') && !line.startsWith('\t') && line.endsWith(':')) {
      section = line.substring(0, line.length - 1);
      map[section] = <String, dynamic>{};
      continue;
    }
    if (section != null && line.trimLeft().contains(':')) {
      final trimmed = line.trimLeft();
      final idx = trimmed.indexOf(':');
      final key = trimmed.substring(0, idx).trim();
      var value = trimmed.substring(idx + 1).trim();
      if (value.isEmpty) {
        value = 'true';
      }
      (map[section] as Map<String, dynamic>)[key] = value;
    } else if (section == 'packages' && line.trimLeft().startsWith('"')) {
      final trimmed = line.trim();
      final name = trimmed.split(':').first.replaceAll('"', '');
      if (map['packages'] is! Map) {
        map['packages'] = <String, dynamic>{};
      }
      (map['packages'] as Map<String, dynamic>)[name] = <String, dynamic>{};
    } else if (section == 'packages' && line.contains('version:')) {
      final m = RegExp(r'version:\s*"?([^"\s]+)"?').firstMatch(line);
      if (m != null) {
        final keys = (map['packages'] as Map).keys.toList();
        if (keys.isNotEmpty) {
          final last = keys.last as String;
          (map['packages'] as Map<String, dynamic>)[last]!['version'] = m.group(
            1,
          );
        }
      }
    }
  }
  return map;
}
