{
  description = "ztd flake";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs = { zig2nix, ... }: let
    flake-utils = zig2nix.inputs.flake-utils;
  in (flake-utils.lib.eachDefaultSystem (system: let
      # Zig flake helper
      # Check the flake.nix in zig-flake project for more options:
      # <https://github.com/Cloudef/mach-flake/blob/master/flake.nix>
      env = zig2nix.outputs.zig-env.${system} {
        zig = zig2nix.outputs.packages.${system}.zig.master.bin;
        customRuntimeDeps = [];
      };
    in rec {
      # nix run .
      apps.default = apps.test;

      # nix run .#build
      apps.build = env.app [] "zig build \"$@\"";

      # nix run .#test
      apps.test = env.app [] "zig build test -- \"$@\"";

      # nix run .#docs
      apps.docs = env.app [] "zig build docs -- \"$@\"";

      # nix run .#deps
      apps.deps = env.showExternalDeps;

      # nix run .#zon2json
      apps.zon2json = env.app [env.zon2json] "zon2json \"$@\"";

      # nix run .#zon2json-lock
      apps.zon2json-lock = env.app [env.zon2json-lock] "zon2json-lock \"$@\"";

      # nix run .#zon2nix
      apps.zon2nix = env.app [env.zon2nix] "zon2nix \"$@\"";

      # nix develop
      devShells.default = env.mkShell {};

      # nix run .#readme
      apps.readme = let
        project = "ztd";
      in env.app [] (builtins.replaceStrings ["`"] ["\\`"] ''
      cat <<EOF
      # ${project}

      Yet another "my own std for zig" project. I try to keep it high quality and only include stuff that I actually reuse.

      ---

      [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

      Project is tested on zig version $(zig version)

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
      EOF
      '');
    }));
}
