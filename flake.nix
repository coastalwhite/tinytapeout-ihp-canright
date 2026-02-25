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
            stdenv = pkgs.stdenv;
						LIBRELANE_TAG = "3.0.0.dev44";
          in {
            devShells.default = pkgs.mkShell {
              packages = with pkgs; [
                pythonPlatform.python
                pythonPlatform.venvShellHook
                pythonPlatform.build
                pythonPlatform.tkinter
            
                uv
                gtkwave
                verilator
                iverilog
              ];

              postVenvCreation = ''
                unset CONDA_PREFIX 
                uv pip install -r tt/requirements.txt
								pip install librelane==${LIBRELANE_TAG}
              '';
              venvDir = ".venv";

							PDK           = "ihp-sg13g2";
							PDK_ROOT      = "/home/johndoe/Projects/IHP-Open-PDK";
							LIBRELANE_TAG = LIBRELANE_TAG;

							# fixes libstdc++ issues and libgl.so issues
							LD_LIBRARY_PATH="${stdenv.cc.cc.lib}/lib/:${pkgs.expat}/lib/:${pkgs.cairo}/lib/:/run/opengl-driver/lib/";
            };
          };
      });
}