{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux.default;
  in
  {
    devShells = {
      default = pkgs.mkShell {
        packages = with pkgs; [
        
        ];
      };
    };
  };
}
