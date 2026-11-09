{ config, pkgs, lib, ... }:
let
  user = config.system.primaryUser;
  home = "/Users/${user}";

  # Dictionaries for macSKK (encoding: 3 = EUC-JP, 4 = UTF-8)
  skkDicts = with pkgs.skkDictionaries; [
    { pkg = l;       file = "SKK-JISYO.L";       encoding = 3; }
    { pkg = jinmei;  file = "SKK-JISYO.jinmei";  encoding = 3; }
    { pkg = geo;     file = "SKK-JISYO.geo";     encoding = 3; }
    { pkg = station; file = "SKK-JISYO.station"; encoding = 3; }
    { pkg = emoji;   file = "SKK-JISYO.emoji";   encoding = 4; }
  ];

  # macSKK romaji-to-kana rules on top of the defaults: full-width ! and ? in kana modes
  skkKanaRule = pkgs.writeText "kana-rule.conf" ''
    #!use-default
    !,！
    ?,？
  '';

  # Lima VM for Docker (rootless template:docker, home mounted writable)
  limactl = "${pkgs.lima}/bin/limactl";
  docker = "${pkgs.docker-client}/bin/docker";
  limaDockerExists = "${limactl} list -q 2>/dev/null | /usr/bin/grep -qx docker";

  # Starts the VM at login. Does nothing if the VM is missing: `limactl start` would otherwise create one
  # without the writable mount. The VM is created by postActivation on switch.
  limaDockerStart = pkgs.writeShellScript "lima-docker-start" ''
    ${limaDockerExists} || exit 0
    exec ${limactl} start --tty=false docker
  '';

  # Built-in window tiling shortcuts (symbolichotkeys). The defaults use Fn+Control, and the Advantage360
  # firmware takes Fn, so use Control+Option instead.
  # parameters are [character code (65535 for arrows), key code, modifiers]. Modifiers are
  # Control (0x40000) + Option (0x80000); arrow keys also carry the Fn flag (0x800000).
  ctrlOpt = 786432;
  ctrlOptArrow = 9175040;
  tileHotKeys = {
    "240" = [ 65535 123 ctrlOptArrow ];   # left half, ←
    "241" = [ 65535 124 ctrlOptArrow ];   # right half, →
    "242" = [ 65535 126 ctrlOptArrow ];   # top half, ↑
    "243" = [ 65535 125 ctrlOptArrow ];   # bottom half, ↓
    "237" = [ 102 3 ctrlOpt ];            # fill, F
  };
  tileHotKeyCommands = lib.concatStrings (lib.mapAttrsToList (id: params: ''
    as_user defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${id} \
      '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array>${lib.concatMapStrings (p: "<integer>${toString p}</integer>") params}</array><key>type</key><string>standard</string></dict></dict>'
  '') tileHotKeys);
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nix.enable = false;            # Determinate Nix manages Nix itself
  system.primaryUser = "kenchan";
  system.stateVersion = 6;

  environment.systemPackages = with pkgs; [
    git
    gh                                 # used by git-credential-gh in dotfiles; from Nix so GUI apps and Claude Code see it too, not just fish
    mise

    # CLI tools (language runtimes and dev tools come from mise)
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

    # Docker: rootless dockerd runs in a Lima VM; the Mac only has the CLI
    lima
    docker-client
    docker-compose
    docker-buildx
  ];

  # Lets docker find compose and buildx as CLI plugins
  environment.pathsToLink = [ "/libexec/docker" ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "1password-cli" ];

  # 1Password CLI, installed as /usr/local/bin/op for the app integration
  programs._1password.enable = true;

  environment.variables.HOMEBREW_NO_ANALYTICS = "1";

  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # The login shell is fish (set in postActivation below). Activate mise in zsh too, for things that use
  # zsh such as Claude Code's command execution. fish activates mise in dotfiles' config.fish.
  programs.zsh.interactiveShellInit = ''
    eval "$(${pkgs.mise}/bin/mise activate zsh)"
  '';

  homebrew = {
    enable = true;
    onActivation = {
      # switch only applies; apps are upgraded separately with `brew update && brew upgrade`
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";          # "zap" or "uninstall" would also remove apps installed outside casks, such as ones MDM deploys
      # environment.variables does not reach the brew that switch runs under sudo
      extraEnv.HOMEBREW_NO_ANALYTICS = "1";
    };
    brews = [ ];
    casks = [
      "1password"                      # where it is already installed (e.g. by MDM), adopt it first: see README
      "brave-browser"
      "chatgpt"                        # includes the Codex desktop app since 2026-07
      "claude-code@latest"             # the CLI, latest channel ("claude-code" is stable)
      "ghostty"
      "herdr-app"
      "macskk"
      "notion"
    ];
    masApps = { };               # e.g. "Xcode" = 497799835;
  };

  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 48;
      mru-spaces = false;              # don't rearrange Spaces by recent use
    };
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXPreferredViewStyle = "Nlsv";   # list view
    };
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      ApplePressAndHoldEnabled = false;
      # No automatic correction or substitution
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
    };
    trackpad.Clicking = true;          # tap to click
    screencapture = {
      location = "${home}/Pictures/Screenshots";
      disable-shadow = true;
    };
    CustomUserPreferences = {
      # No .DS_Store on network and USB volumes
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      # Don't reopen apps and windows after logging back in
      "com.apple.loginwindow" = {
        TALLogoutSavesState = false;
        LoginwindowLaunchesRelaunchApps = false;
      };
      "net.mtgto.inputmethod.macSKK" = {
        showAnnotation = false;        # no system dictionary annotations next to candidates
        kanaRule = "kana-rule.conf";   # installed by preActivation below
        # Enabled dictionaries; the files are installed by preActivation below
        dictionaries = map (d: {
          filename = d.file;
          inherit (d) encoding;
          enabled = true;
          saveToUserDict = true;
          type = "traditional";
        }) skkDicts;
        # No date conversion: by default きょう, あした, today, ... convert to dates and hide the dictionary words.
        # The formats are macSKK's defaults, kept so that adding a reading in Settings turns it back on.
        dateConversions = {
          yomis = [ ];
          conversions = [
            { format = "yyyy/MM/dd"; locale = "en_US"; calendar = "gregorian"; }
            { format = "yyyy-MM-dd"; locale = "en_US"; calendar = "gregorian"; }
            { format = "yyyy年M月d日"; locale = "en_US"; calendar = "gregorian"; }
            { format = "Gy年M月d日"; locale = "ja_JP"; calendar = "japanese"; }
          ];
        };
      };
    };
  };

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  # system.keyboard only runs hidutil during activation and the mapping is lost on reboot, so apply it at every login
  launchd.user.agents.keyboard-remap.serviceConfig = {
    ProgramArguments = [
      "/usr/bin/hidutil" "property" "--set"
      (builtins.toJSON { UserKeyMapping = config.system.keyboard.userKeyMapping; })
    ];
    RunAtLoad = true;
  };

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;                   # Touch ID inside terminal multiplexers such as herdr-core too
  };

  # launchd jobs that run executables under /nix are written with `command`, which starts them through
  # /bin/sh and waits for /nix/store, so launchd does not disable a job that loads before /nix is mounted.

  # Start the Lima VM for Docker at login
  launchd.user.agents.lima-docker = {
    command = "${limaDockerStart}";
    serviceConfig = {
      RunAtLoad = true;
      StandardOutPath = "/tmp/lima-docker.log";
      StandardErrorPath = "/tmp/lima-docker.log";
    };
  };

  # macOS selects ABC at login, so set the input sources to macSKK as on switch.
  # Wait a moment first, since macOS restores its own input source right after login.
  launchd.user.agents.input-sources = {
    command = "${pkgs.writeShellScript "input-sources-at-login" ''
      sleep 5
      exec /usr/bin/osascript -l JavaScript ${./input-sources.js} '/Library/Input Methods/macSKK.app'
    ''}";
    serviceConfig = {
      RunAtLoad = true;
      StandardOutPath = "/tmp/input-sources.log";
      StandardErrorPath = "/tmp/input-sources.log";
    };
  };

  system.activationScripts.postActivation.text = ''
    # Run as the user in the logged-in GUI session (needed for the Lima VM and input sources)
    as_user() { launchctl asuser "$(id -u ${user})" sudo --user=${user} --set-home -- "$@"; }

    # Make fish the login shell. users.users.<name>.shell only applies to users in users.knownUsers,
    # and the MDM-created account should stay outside nix-darwin, so change just the shell with dscl.
    if [ "$(dscl . -read /Users/${user} UserShell | awk '{print $2}')" != /run/current-system/sw/bin/fish ]; then
      dscl . -create /Users/${user} UserShell /run/current-system/sw/bin/fish
    fi

    # Screenshot folder
    install -d -o ${user} -g staff ${home}/Pictures/Screenshots

    # Link Nix's docker CLI plugins to where docker looks for them by default
    install -d /usr/local/lib/docker
    ln -sfn /run/current-system/sw/libexec/docker/cli-plugins /usr/local/lib/docker/cli-plugins

    # Create the Lima VM for Docker and the docker context if missing.
    # The first time downloads an image and takes a few minutes. Failures don't stop the switch.
    if ! as_user sh -c '${limaDockerExists}'; then
      echo "Creating the Lima VM for Docker (the first time downloads an image and takes a few minutes)..." >&2
      as_user ${limactl} start --name=docker --mount-writable --tty=false template:docker \
        || echo "warning: failed to create the Lima VM; create it by hand (see Docker in README)" >&2
    fi
    if ! as_user ${docker} context inspect lima-docker >/dev/null 2>&1; then
      as_user ${docker} context create lima-docker --docker "host=unix://${home}/.lima/docker/sock/docker.sock" >/dev/null \
        && as_user ${docker} context use lima-docker >/dev/null \
        || echo "warning: failed to create the docker context lima-docker" >&2
    fi

    # Set the input sources to macSKK (ASCII and hiragana modes) and switch away from ABC (input-sources.js).
    # The macSKK cask is installed earlier, in the Homebrew step.
    if [ -d "/Library/Input Methods/macSKK.app" ]; then
      as_user /usr/bin/osascript -l JavaScript ${./input-sources.js} "/Library/Input Methods/macSKK.app" \
        || echo "warning: failed to set the input sources" >&2
    fi

    # Window tiling shortcuts. symbolichotkeys also holds the input source and Spaces shortcuts, so add only
    # these entries instead of replacing the whole plist with CustomUserPreferences, then apply without logging out.
    ${tileHotKeyCommands}
    as_user /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

    # Opt out of Homebrew analytics in its own settings too, for brew runs outside a shell.
    # Only when brew exists, so a missing Homebrew doesn't stop the whole switch.
    if [ -x /opt/homebrew/bin/brew ]; then
      sudo --user=${user} --set-home -- /opt/homebrew/bin/brew analytics off
    fi
  '';

  # Install the macSKK dictionaries. Copies rather than symlinks, because macSKK reads them from its sandbox.
  # A running macSKK registers new files as disabled, so put them in place before dictionaries is written.
  system.activationScripts.preActivation.text = ''
    dir="${home}/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries"
    if [ -d "$dir" ]; then
      for f in ${lib.concatMapStringsSep " " (d: "${d.pkg}/share/skk/${d.file}") skkDicts}; do
        cmp -s "$f" "$dir/$(basename "$f")" || install -m 0644 -o ${user} -g staff "$f" "$dir/"
      done
    else
      echo "Skipping macSKK dictionaries: the folder does not exist yet (launch macSKK once, then switch again)" >&2
    fi

    settings="${home}/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Settings"
    if [ -d "$settings" ]; then
      cmp -s ${skkKanaRule} "$settings/kana-rule.conf" || install -m 0644 -o ${user} -g staff ${skkKanaRule} "$settings/kana-rule.conf"
    fi
  '';
}
