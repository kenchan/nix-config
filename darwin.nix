{ config, pkgs, lib, ... }:
let
  user = config.system.primaryUser;
  home = "/Users/${user}";
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.enable = false;            # Determinate Nix を使うため
  system.primaryUser = "kenchan";
  system.stateVersion = 6;

  environment.systemPackages = with pkgs; [ git mise ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "1password-cli" ];

  # 1Password CLI(アプリ連携のため /usr/local/bin/op に置かれる)
  programs._1password.enable = true;

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";          # 慣れたら "zap"(リストにないアプリを削除)
    };
    brews = [ ];
    casks = [
      "macskk"
    ];
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
      # 自動修正・自動置換をオフ
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
    };
    trackpad.Clicking = true;          # タップでクリック
    screencapture = {
      location = "${home}/Pictures/Screenshots";
      disable-shadow = true;
    };
    CustomUserPreferences = {
      # ネットワークドライブと USB に .DS_Store を作らない
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  # macSKK の辞書を配置(サンドボックス内から読むのでシンボリックリンクではなくコピー)
  system.activationScripts.postActivation.text = ''
    # スクリーンショットの保存先
    install -d -o ${user} -g staff ${home}/Pictures/Screenshots

    dir="${home}/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    if [ -d "$dir" ]; then
      for f in ${pkgs.skkDictionaries.l}/share/skk/SKK-JISYO.L ${pkgs.skkDictionaries.jinmei}/share/skk/SKK-JISYO.jinmei; do
        cmp -s "$f" "$dir/$(basename "$f")" || install -m 0644 -o ${user} -g staff "$f" "$dir/"
      done
    else
      echo "macSKK の辞書フォルダがないのでスキップ(macSKK を一度起動してください)" >&2
    fi
  '';
}
