# ztd

Yet another "my own std for zig" project. I try to keep it high quality and only include stuff that I actually reuse.

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Project is tested on zig version 0.15.0-dev.27+17b40b1d6

## Depend

`build.zig.zon`
```zig
.ztd = .{
  .url = "https://github.com/Cloudef/ztd/archive/{COMMIT}.tar.gz",
  .hash = "{HASH}",
},
```

`build.zig`
```zig
const ztd = b.dependency("ztd", .{}).module("ztd");
exe.root_module.addImport("ztd", ztd);
```

## You might also like

- [nektro/zig-extras](https://github.com/nektro/zig-extras)
