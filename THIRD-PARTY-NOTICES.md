# Third-party notices

This project (source-available under the Elastic License 2.0 — see `LICENSE`) vendors two
pieces of third-party JavaScript directly into `assets/vendor/`. Their own licenses are
independent of, and unaffected by, the license this repository is distributed under; both
require preserving attribution, which this file and the headers in the vendored files do.

## topbar

- **Source:** https://buunguyen.github.io/topbar (v2.0.0)
- **Vendored at:** `assets/vendor/topbar.js`
- **Copyright:** (c) 2021 Buu Nguyen
- **License:** MIT

```
Copyright (c) 2021 Buu Nguyen

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice (including the next paragraph) shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

## @material/material-color-utilities

- **Source:** https://github.com/material-foundation/material-color-utilities (0.3.0, bundled
  via jsDelivr with Rollup/esbuild)
- **Vendored at:** `assets/vendor/material-color-utilities.js`
- **Copyright:** 2021 Google LLC
- **License:** Apache License, Version 2.0 — full text at
  https://www.apache.org/licenses/LICENSE-2.0 (reproduced in full here rather than inline for
  length; not modified from upstream, and the project does not ship a `NOTICE` file to carry
  forward).

This file is used as-is (minified/bundled by the upstream CDN, not further modified by this
project) for OKLCH-based theme color derivation — see `assets/js/hooks/logo_theme.js`.
