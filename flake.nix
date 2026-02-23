{
  description = "A basic Nix Flake for eachDefaultSystem";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];
        perSystem =
          {
            system,
            pkgs,
            lib,
            self',
            ...
          }: 
          let
            pythonPlatform = lib.recursiveUpdate {
              python = pkgs.python311;
            } pkgs.python311Packages;
          in {
            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                pythonPlatform.python
                pythonPlatform.venvShellHook
                pythonPlatform.build
            
                uv
                gtkwave
                verilator
                iverilog
              ];

              postVenvCreation = ''
                unset CONDA_PREFIX 
              '';
              venvDir = ".venv";
            };
          };
      });
}