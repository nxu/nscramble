{
  description = "nscramble dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" ];
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # NoCC: keep Xcode's swift/clang/SDK instead of the nix stdenv toolchain.
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              bun
              just
              xcodegen
            ];
          };
        }
      );
    };
}
