{ config, pkgs, lib, ... }:
let
  user = config.system.primaryUser;
  home = "/Users/${user}";

  # macSKK で使う辞書(encoding: 3 = EUC-JP, 4 = UTF-8)
  skkDicts = with pkgs.skkDictionaries; [
    { pkg = l;       file = "SKK-JISYO.L";       encoding = 3; }
    { pkg = jinmei;  file = "SKK-JISYO.jinmei";  encoding = 3; }
    { pkg = geo;     file = "SKK-JISYO.geo";     encoding = 3; }
    { pkg = station; file = "SKK-JISYO.station"; encoding = 3; }
    { pkg = emoji;   file = "SKK-JISYO.emoji";   encoding = 4; }
  ];
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
      "amethyst"
      "herdr-app"
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
      # 再ログイン時に前回のアプリやウインドウを開き直さない
      "com.apple.loginwindow" = {
        TALLogoutSavesState = false;
        LoginwindowLaunchesRelaunchApps = false;
      };
      # macSKK: 変換候補の横にシステム辞書の注釈を出さない
      "net.mtgto.inputmethod.macSKK" = {
        showAnnotation = false;
        # 有効にする辞書(ファイルは下の postActivation で配置)
        dictionaries = map (d: {
          filename = d.file;
          inherit (d) encoding;
          enabled = true;
          saveToUserDict = true;
          type = "traditional";
        }) skkDicts;
      };
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  # ログイン時に Amethyst を起動
  launchd.user.agents.amethyst.serviceConfig = {
    ProgramArguments = [ "/usr/bin/open" "-a" "Amethyst" ];
    RunAtLoad = true;
  };

  system.activationScripts.postActivation.text = ''
    # スクリーンショットの保存先
    install -d -o ${user} -g staff ${home}/Pictures/Screenshots
  '';

  # macSKK の辞書を配置(サンドボックス内から読むのでシンボリックリンクではなくコピー)。
  # 起動中の macSKK は新しいファイルを無効として登録するので、dictionaries の書き込みより前に置く
  system.activationScripts.preActivation.text = ''
    dir="${home}/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    if [ -d "$dir" ]; then
      for f in ${lib.concatMapStringsSep " " (d: "${d.pkg}/share/skk/${d.file}") skkDicts}; do
        cmp -s "$f" "$dir/$(basename "$f")" || install -m 0644 -o ${user} -g staff "$f" "$dir/"
      done
    else
      echo "macSKK の辞書フォルダがないのでスキップ(macSKK を一度起動してください)" >&2
    fi
  '';
}
