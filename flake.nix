{
  description = "kenchan's Mac";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nix-darwin, ... }: {
    # ホスト名に依存しないよう名前を固定する。適用時は `--flake ~/src/github.com/kenchan/nix-config#default`
    darwinConfigurations.default = nix-darwin.lib.darwinSystem {
      modules = [ ./darwin.nix ];
    };
  };
}
