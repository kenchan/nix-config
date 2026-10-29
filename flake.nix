{
  description = "kenchan's Mac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nix-darwin, ... }: {
    darwinConfigurations.default = nix-darwin.lib.darwinSystem {
      modules = [ ./darwin.nix ];
    };
  };
}
