// SPDX-License-Identifier: Apache-2.0

import 'page_title_stub.dart'
    if (dart.library.html) 'page_title_web.dart'
    as impl;

void setDocumentTitle(String title) => impl.setDocumentTitle(title);
