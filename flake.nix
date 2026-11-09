{
  description = "kenchan's Mac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nix-darwin, ... }: {
    # A fixed name instead of the hostname; apply with `--flake ~/src/github.com/kenchan/nix-config#default`
    darwinConfigurations.default = nix-darwin.lib.darwinSystem {
      modules = [ ./darwin.nix ];
    };
  };
}
