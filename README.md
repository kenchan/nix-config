# nix-darwin

Mac の macOS 設定とアプリを管理する nix-darwin の flake。
設定の名前はホスト名ではなく `default` に固定しているので、適用時は `#default` を付ける(付けないとホスト名で探して失敗する)。
言語ランタイムは mise、シェルやエディタの設定は [dotfiles](https://github.com/kenchan/dotfiles) で管理する。

## 適用

```sh
sudo darwin-rebuild switch --flake ~/.config/nix-darwin#default
```

更新(nixpkgs / nix-darwin / SKK 辞書):

```sh
nix flake update --flake ~/.config/nix-darwin
sudo darwin-rebuild switch --flake ~/.config/nix-darwin#default
```

古い世代の掃除(Determinate Nix なので `nix.gc` は使えない):

```sh
sudo nix-collect-garbage --delete-older-than 30d
```

## 新しい Mac のセットアップ

1. `xcode-select --install`
2. Nix(Determinate):`curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
3. Homebrew:`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
4. このリポジトリを `~/.config/nix-darwin` に置く
5. 初回だけ:`sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/.config/nix-darwin#default`
6. dotfiles:
   ```sh
   git clone https://github.com/kenchan/dotfiles.git ~/src/github.com/kenchan/dotfiles
   cd ~/src/github.com/kenchan/dotfiles
   mise trust
   mise dotfiles apply --force '~/.config' '~/.config/nvim' '~/.local/bin' '~/.apm'
   ```
   `~/.claude` は WSL 向けの設定(`/home/kenchan` のパス、GNU sed 前提のフック)なので Mac では配置しない
7. 下の「手作業」をやる

## 手作業(Nix で管理していないもの)

### 入力ソース
macOS の入力ソースは `defaults` では安定して管理できないので手で設定する。

- 「システム設定」→「キーボード」→「入力ソース」→「編集…」
- macSKK の **ひらがな**(「日本語」の中)と **ASCII**(「英語」の中)を追加
- ABC は macOS の制約で消せないので残す
- 「キーボードショートカット」→「入力ソース」の「前の入力ソースを選択」をオフにすると ABC に切り替わりにくい

macSKK を一度起動してから `darwin-rebuild switch` すると辞書が配置・有効化される。

### git / gh
署名(1Password)と HTTPS の認証(`git-credential-gh`)は dotfiles 側で Mac にも対応しているので、`~/.config/git/config.local` は空でよい。
gh(Nix で入れている)に各アカウントでログインする:

```sh
gh auth login --hostname github.com --git-protocol https --web     # アカウントごとに
```

- 「Authenticate Git with your GitHub credentials?」は **n**(`Y` だと dotfiles の `~/.config/git/config` に書き込まれる)
- 同じホストに複数のアカウントがあるときは、リポジトリで `git config credential.username <アカウント>` を設定して選ぶ

### 1Password
- 「設定」→「開発者」で **1Password CLI と連携** をオン(`op vault list` で Touch ID が出れば OK)
- 同じ画面で **SSH エージェントを使用** をオン
- `~/.ssh/config`:
  ```sshconfig
  Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  ```

### Herdr
- Herdr.app を起動すると herdr-core のインストールを案内される(`~/.local/bin/herdr-core` と `hc`)
- `~/.config/herdr-core/config.toml`(Nix の fish のパスなので Mac 専用。dotfiles には入れない):
  ```toml
  shell = ["/run/current-system/sw/bin/fish"]
  ```

### Docker(Lima の rootless Docker)
Mac 側は Nix の docker CLI(compose / buildx 付き)だけで、dockerd は Lima の VM で rootless で動かす。
VM はログイン時に `launchd.user.agents.lima-docker` が起動する。初回だけ VM と context を作る:

```sh
limactl start --name=docker --mount-writable --tty=false template:docker
docker context create lima-docker --docker "host=unix://$HOME/.lima/docker/sock/docker.sock"
docker context use lima-docker
docker run --rm hello-world
```

- `--mount-writable` がないとホームが読み取り専用でマウントされ、bind mount に書けない
- 既存の VM を変えるときは `limactl stop docker && limactl edit --mount-writable docker && limactl start docker`
- VM の起動ログは `/tmp/lima-docker.log`

### Amethyst
- 初回起動時に「システム設定」→「プライバシーとセキュリティ」→「アクセシビリティ」で許可し、Amethyst を再起動する
- 自動起動は Nix(`launchd.user.agents.amethyst`)で行うので、Amethyst の「Start at login」はオフのまま

### Kensington SlimBlade
- Kensington のサイトから公式アプリ(Kensington Konnect)を入れる。Homebrew にない
- アクセシビリティと入力監視を許可する

### ログイン項目
- 「システム設定」→「一般」→「ログイン項目と機能拡張」で、アプリ自身が登録した「ログイン時に開く」を整理する
- MDM が管理しているものは触らない
