{ pkgs, ... }: {
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.enable = false;            # Determinate Nix を使うため
  system.primaryUser = "kenchan";
  system.stateVersion = 6;

  environment.systemPackages = with pkgs; [ git mise ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";          # 慣れたら "zap"(リストにないアプリを削除)
    };
    brews = [ ];
    casks = [ ];
    masApps = { };               # 例: "Xcode" = 497799835;
  };

  system.defaults = {
    dock = { autohide = true; show-recents = false; tilesize = 48; };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXPreferredViewStyle = "Nlsv";   # リスト表示
    };
    NSGlobalDomain = {
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
    };
    trackpad.Clicking = true;          # タップでクリック
  };

  security.pam.services.sudo_local.touchIdAuth = true;
}
