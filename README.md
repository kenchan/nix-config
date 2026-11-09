# nix-config

nix-darwin flake for my Mac: macOS settings, CLI tools, and GUI apps.
Language runtimes and dev tools come from mise, and shell/editor settings from
[dotfiles](https://github.com/kenchan/dotfiles).

| What | Managed by |
|---|---|
| macOS settings, CLI tools | nix-darwin (this repository), on [Determinate Nix](https://determinate.systems/) |
| GUI apps | nix-darwin's Homebrew module (casks) |
| Language runtimes, dev tools | mise (`config/mise/config.toml` in dotfiles) |
| Shell, editor, git settings | dotfiles (mise `[dotfiles]`) |

home-manager is not used: dotfiles are shared with Linux (WSL) machines and deployed by mise.

## Apply

The configuration is named `default` rather than after the hostname, so always pass `#default`
(without it, `darwin-rebuild` looks for the hostname and fails):

```sh
sudo darwin-rebuild switch --flake ~/src/github.com/kenchan/nix-config#default
```

`switch` only applies the configuration; it does not upgrade anything. Homebrew installs newly added
casks but never upgrades or uninstalls (`onActivation.cleanup = "none"`), so after removing an app from
`casks`, uninstall it by hand:

```sh
brew uninstall --cask <name>
```

## Update

`update-world` in dotfiles updates everything. On macOS it runs the steps that ask for Touch ID first:

1. `nix flake update` and `darwin-rebuild switch`
2. `brew update` and `brew upgrade`
3. mise tools, fish plugins, gh extensions, and other tools
4. `apt-get full-upgrade` in the Lima VM, restarting the VM when a reboot is required

Pass tokens from the caller. `GITHUB_TOKEN` avoids GitHub API rate limits (for Nix and mise), and
`MISE_GITHUB_ENTERPRISE_TOKEN` is needed when mise installs tools from a GitHub Enterprise host:

```sh
GITHUB_TOKEN=$(gh auth token) mise run update-world
```

Commit `flake.lock` once the new versions work.

Clean up old generations by hand when you like (`nix.gc` is unavailable with Determinate Nix).
Determinate's own automatic GC only frees unreferenced paths under disk pressure and keeps generations:

```sh
sudo nix-collect-garbage --delete-older-than 7d
```

## Setting up a new Mac

1. `xcode-select --install`
2. Determinate Nix: `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
3. Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
4. Clone this repository into the ghq layout with the Command Line Tools' git (ghq is not installed yet):
   ```sh
   git clone https://github.com/kenchan/nix-config.git ~/src/github.com/kenchan/nix-config
   ```
5. First switch: `sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/src/github.com/kenchan/nix-config#default`
   - Run it while logged in to the GUI and online; it downloads the Lima VM image, which takes a few minutes.
   - Then switch again with `darwin-rebuild`. macSKK creates its dictionary folder on first launch
     (at the end of the first switch), so the dictionaries are installed by the second one.
6. Open a new terminal (so the Nix paths are on `PATH`) and set up dotfiles:
   ```sh
   git clone https://github.com/kenchan/dotfiles.git ~/src/github.com/kenchan/dotfiles
   cd ~/src/github.com/kenchan/dotfiles
   mise trust
   mise bootstrap                      # dotfiles links, mise tools, fish plugins
   herdr integration install claude    # Claude Code SessionStart hook (written to ~/.claude/settings.json)
   ```
   If a link fails because a file already exists, check it and run `mise dotfiles apply --force`.
7. Do the manual steps below.

## What switch sets up

### Login shell

fish (`/run/current-system/sw/bin/fish`), so Ghostty, Terminal.app, and Herdr open fish without per-app
settings. It is set with `dscl` on switch: `users.users.<name>.shell` only applies to users in
`users.knownUsers`, and the MDM-created account should stay outside nix-darwin.

If Nix breaks and fish disappears, terminals close immediately (booting and GUI login are unaffected).
Change the login shell back to `/bin/zsh` in System Settings → Users & Groups → right-click your user →
Advanced Options.

### Input sources and macSKK

`input-sources.js` sets the input sources on switch and at login (`launchd.user.agents.input-sources`).
It calls the TIS API from osascript, because writing `com.apple.HIToolbox` with `defaults` does not apply
reliably.

- It enables macSKK with its **ASCII** and **hiragana** modes, and switches to ASCII unless macSKK is
  already selected.
- The hiragana mode is an input source too, so Ctrl+J changes the input source itself and Ghostty can tell
  the IME handled it. With ASCII alone, Ghostty also sends Ctrl+J as a newline. dotfiles additionally sets
  `keybind = ctrl+j=ignore` for Ghostty.
- Terminal.app handles keys before the IME, so Ctrl+J cannot switch to hiragana there. Use Ghostty.
- ABC cannot be removed (macOS requires a keyboard layout).

SKK dictionaries (L, jinmei, geo, station, emoji) come from nixpkgs and are copied into macSKK's sandbox
container on switch.

### Keyboard

Caps Lock is Control. `system.keyboard` only runs `hidutil` during activation and the mapping is lost on
reboot, so a login agent applies it again.

### Window tiling

macOS's built-in tiling: drag to a screen edge, hover over the green button, or use the keys below.
The default shortcuts use Fn, which the Advantage360 firmware takes for itself, so switch rewrites the
system shortcuts (`com.apple.symbolichotkeys` 237 and 240–243, the same ones Keyboard Shortcuts edits).
Only those entries are added, since the same plist holds the input source and Spaces shortcuts.

| Keys | Action |
|---|---|
| Control+Option+← / → | Left / right half |
| Control+Option+↑ / ↓ | Top / bottom half |
| Control+Option+F | Fill |

Auto-tiling window managers (Amethyst) were dropped because windows jump around whenever one opens or
closes. Google Sheets and Docs take Control+Option shortcuts for themselves.

### Docker (rootless, in a Lima VM)

The Mac has only the Docker CLI from Nix (with compose and buildx); dockerd runs rootless in a Lima VM.
Docker Desktop and OrbStack need paid licenses for company use.

On switch, the VM (`docker`) and the docker context (`lima-docker`) are created if missing (the first
time downloads an image). A login agent starts the VM, and does nothing if it does not exist.

To create it by hand (delete a half-created VM first, since switch does not recreate an existing one):

```sh
limactl delete --force docker
limactl start --name=docker --mount-writable --tty=false template:docker
docker context create lima-docker --docker "host=unix://$HOME/.lima/docker/sock/docker.sock"
docker context use lima-docker
docker run --rm hello-world
```

- `template:docker` runs rootless dockerd (`docker info` shows `name=rootless` in SecurityOptions).
- Without `--mount-writable`, the home directory is mounted read-only and bind mounts cannot be written.
- Nix only creates the VM when it is missing. Recreate it to change its settings (CPUs, memory, ...).
- Security updates come from unattended-upgrades inside the VM; `update-world` upgrades the rest.
- The login agent's log is `/tmp/lima-docker.log`.

### launchd jobs that run /nix binaries

They are written with `command`, which starts them through `/bin/sh` and waits for `/nix/store`, so
launchd does not disable a job that loads before `/nix` is mounted at boot.

## Manual steps

### git and gh

Commit signing (1Password) and HTTPS authentication (`git-credential-gh`) are set up by dotfiles.
`~/.config/git/config.local` holds machine-specific settings only, such as which account to use per URL.
Log in to gh for each account:

```sh
gh auth login --hostname github.com --git-protocol https --web
```

- Answer **n** to "Authenticate Git with your GitHub credentials?". **Y** writes into
  `~/.config/git/config`, which is a symlink into dotfiles.
- With several accounts on one host, pick one with `credential.<url>.username` in `config.local`,
  or with `git config credential.username <account>` in a repository.

### 1Password

- Install the app yourself. It is not a cask: on Macs where MDM already installed it, Homebrew fails with
  "already an app" and stops the whole switch, and adopting it (`--adopt`) is blocked by macOS's
  App Management protection. The `op` CLI comes from `programs._1password`.
- In Settings → Developer, turn on **Integrate with 1Password CLI** (`op vault list` should ask for
  Touch ID) and **Use the SSH agent**.
- `~/.ssh/config`:
  ```sshconfig
  Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  ```

### Input sources

In Keyboard Shortcuts → Input Sources, turn off "Select the previous input source" so you do not end up
in ABC by accident.

### Herdr

Herdr.app offers to install herdr-core (`~/.local/bin/herdr-core` and `hc`) on first launch.
The herdr CLI itself comes from mise.

### Kensington SlimBlade

Install Kensington Konnect from Kensington's site (it is not on Homebrew), and allow Accessibility and
Input Monitoring.

### Login items

Clean up "Open at Login" entries that apps register in System Settings → General → Login Items &
Extensions. Leave the ones managed by MDM alone.
