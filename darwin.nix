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

  # macSKK のローマ字かな変換ルール(デフォルトとの差分)
  skkKanaRule = pkgs.writeText "kana-rule.conf" ''
    #!use-default
    !,！
    ?,？
  '';

  # Docker 用の Lima VM(rootless の template:docker、ホームは書き込み可でマウント)
  limactl = "${pkgs.lima}/bin/limactl";
  docker = "${pkgs.docker-client}/bin/docker";
  limaDockerExists = "${limactl} list -q 2>/dev/null | /usr/bin/grep -qx docker";

  # ログイン時に VM を起動する。VM が無いときは何もしない(作るのは switch 時の postActivation)
  limaDockerStart = pkgs.writeShellScript "lima-docker-start" ''
    ${limaDockerExists} || exit 0
    exec ${limactl} start --tty=false docker
  '';

  # 標準のタイル機能で半分に寄せるキー(symbolichotkeys の 240〜243)。既定の Fn+Control+矢印は Advantage360 では
  # Fn がファームウェアに取られて押せないので Control+Option+矢印にする。
  # 修飾キーの値は Control(0x40000) + Option(0x80000) + 矢印キーに付く Fn フラグ(0x800000)
  tileHotKeys = { "240" = 123; "241" = 124; "242" = 126; "243" = 125; };   # ← → ↑ ↓ のキーコード
  tileHotKeyCommands = lib.concatStrings (lib.mapAttrsToList (id: keyCode: ''
    as_user defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${id} \
      '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>${toString keyCode}</integer><integer>9175040</integer></array><key>type</key><string>standard</string></dict></dict>'
  '') tileHotKeys);
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.enable = false;            # Determinate Nix を使うため
  system.primaryUser = "kenchan";
  system.stateVersion = 6;

  environment.systemPackages = with pkgs; [
    git
    gh                                 # dotfiles の git-credential-gh が使う。fish 以外(GUI や Claude Code)からも見えるように
    mise

    # wsl-setup で入れていた CLI(言語やランタイムは mise で管理)
    bat
    consul-template
    direnv
    doggo
    duckdb
    fd
    ffmpeg
    fzf
    gnupg
    imagemagick
    jpegoptim
    kubectl
    kubectx
    kubeseal
    lsd
    neovim
    nkf
    pngquant
    poppler-utils
    ripgrep
    socat
    starship
    wget

    # Docker: Lima の VM で rootless の dockerd を動かし、Mac 側は CLI だけ
    lima
    docker-client
    docker-compose
    docker-buildx
  ];

  # docker compose / docker buildx をプラグインとして見つけられるようにする
  environment.pathsToLink = [ "/libexec/docker" ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "1password-cli" ];

  # 1Password CLI(アプリ連携のため /usr/local/bin/op に置かれる)
  programs._1password.enable = true;

  environment.variables.HOMEBREW_NO_ANALYTICS = "1";

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # ログインシェルは fish(下の postActivation で設定)。zsh を使う場面(Claude Code のコマンド実行など)でも
  # mise のツール(node など)を使えるようにする(fish 側の mise activate は dotfiles の config.fish でやっている)
  programs.zsh.interactiveShellInit = ''
    eval "$(${pkgs.mise}/bin/mise activate zsh)"
  '';

  homebrew = {
    enable = true;
    onActivation = {
      # switch は反映だけにして、アプリの更新は `brew update && brew upgrade` で別にやる
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";          # 慣れたら "zap"(リストにないアプリを削除)
      # sudo で動く switch には environment.variables が渡らないので、ここでも指定する
      extraEnv.HOMEBREW_NO_ANALYTICS = "1";
    };
    brews = [ ];
    casks = [
      "chatgpt"                        # Codex のデスクトップアプリも統合済み(2026-07)
      "claude-code@latest"             # CLI。latest チャンネル(stable は "claude-code")
      "ghostty"
      "herdr-app"
      "macskk"
      "notion"
    ];
    masApps = { };               # 例: "Xcode" = 497799835;
  };

  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 48;
      mru-spaces = false;              # Spaces の並びを自動で入れ替えない
    };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXPreferredViewStyle = "Nlsv";   # リスト表示
    };
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";    # ダークモード
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
        kanaRule = "kana-rule.conf";   # 下の preActivation で配置するルールを使う
        # 有効にする辞書(ファイルは下の preActivation で配置)
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

  # system.keyboard は switch のときに hidutil を実行するだけで、再起動すると消えるので、ログインのたびにかけ直す
  launchd.user.agents.keyboard-remap.serviceConfig = {
    ProgramArguments = [
      "/usr/bin/hidutil" "property" "--set"
      (builtins.toJSON { UserKeyMapping = config.system.keyboard.userKeyMapping; })
    ];
    RunAtLoad = true;
  };

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;                   # herdr-core などのセッション内でも Touch ID を使う
  };

  # ログイン時に Docker 用の Lima VM を起動
  launchd.user.agents.lima-docker.serviceConfig = {
    ProgramArguments = [ "${limaDockerStart}" ];
    RunAtLoad = true;
    StandardOutPath = "/tmp/lima-docker.log";
    StandardErrorPath = "/tmp/lima-docker.log";
  };

  # ログイン時は macOS が ABC を選ぶので、switch のときと同じく macSKK に揃える。
  # ログイン直後は macOS 側の入力ソースの復元と競合しうるので少し待ってから実行する
  launchd.user.agents.input-sources.serviceConfig = {
    ProgramArguments = [
      "/bin/sh" "-c"
      "sleep 5; exec /usr/bin/osascript -l JavaScript ${./input-sources.js} '/Library/Input Methods/macSKK.app'"
    ];
    RunAtLoad = true;
    StandardOutPath = "/tmp/input-sources.log";
    StandardErrorPath = "/tmp/input-sources.log";
  };

  system.activationScripts.postActivation.text = ''
    # ログイン中の GUI セッションのユーザーとして実行する(Lima の VM や入力ソースの操作に必要)
    as_user() { launchctl asuser "$(id -u ${user})" sudo --user=${user} --set-home -- "$@"; }

    # ログインシェルを fish にする。users.users.<名前>.shell は users.knownUsers で管理するユーザーにしか
    # 効かず、MDM が作ったアカウントを nix-darwin の管理下に置きたくないので、シェルだけ dscl で変える
    if [ "$(dscl . -read /Users/${user} UserShell | awk '{print $2}')" != /run/current-system/sw/bin/fish ]; then
      dscl . -create /Users/${user} UserShell /run/current-system/sw/bin/fish
    fi

    # スクリーンショットの保存先
    install -d -o ${user} -g staff ${home}/Pictures/Screenshots

    # docker CLI が標準で探す場所に Nix のプラグインをつなぐ
    install -d /usr/local/lib/docker
    ln -sfn /run/current-system/sw/libexec/docker/cli-plugins /usr/local/lib/docker/cli-plugins

    # Docker 用の Lima VM と docker context を無ければ作る。
    # 初回はイメージのダウンロードで数分かかる。失敗しても switch は止めない
    if ! as_user sh -c '${limaDockerExists}'; then
      echo "Docker 用の Lima VM を作成します(初回はダウンロードに数分かかります)..." >&2
      as_user ${limactl} start --name=docker --mount-writable --tty=false template:docker \
        || echo "警告: Lima VM の作成に失敗しました。README の「Docker」を見て手で作ってください" >&2
    fi
    if ! as_user ${docker} context inspect lima-docker >/dev/null 2>&1; then
      as_user ${docker} context create lima-docker --docker "host=unix://${home}/.lima/docker/sock/docker.sock" >/dev/null \
        && as_user ${docker} context use lima-docker >/dev/null \
        || echo "警告: docker context lima-docker を作れませんでした" >&2
    fi

    # 入力ソースを macSKK(ASCII モードだけ)に揃え、ABC になっていたら切り替える(input-sources.js)。
    # macSKK の cask はこれより前の Homebrew の段階で入る
    if [ -d "/Library/Input Methods/macSKK.app" ]; then
      as_user /usr/bin/osascript -l JavaScript ${./input-sources.js} "/Library/Input Methods/macSKK.app" \
        || echo "警告: 入力ソースを設定できませんでした" >&2
    fi

    # タイル機能のキーを Control+Option+矢印にする。symbolichotkeys には入力ソースや Spaces の切り替えも入っているので、
    # CustomUserPreferences で丸ごと書き換えず、該当の番号だけ書き足してからログインし直さずに反映する
    ${tileHotKeyCommands}
    as_user /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

    # Homebrew の利用状況を送らない(シェル以外から brew が動くときのため設定にも書く)。
    # brew が無いときに switch 全体を止めないよう、あるときだけ実行する
    if [ -x /opt/homebrew/bin/brew ]; then
      sudo --user=${user} --set-home -- /opt/homebrew/bin/brew analytics off
    fi
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

    settings="${home}/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings"
    if [ -d "$settings" ]; then
      cmp -s ${skkKanaRule} "$settings/kana-rule.conf" || install -m 0644 -o ${user} -g staff ${skkKanaRule} "$settings/kana-rule.conf"
    fi
  '';
}
