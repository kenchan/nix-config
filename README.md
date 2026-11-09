# nix-darwin

Mac の macOS 設定とアプリを管理する nix-darwin の flake。
設定の名前はホスト名ではなく `default` に固定しているので、適用時は `#default` を付ける(付けないとホスト名で探して失敗する)。
言語ランタイムは mise、シェルやエディタの設定は [dotfiles](https://github.com/kenchan/dotfiles) で管理する。

## 適用

設定を変えたら反映する(何も更新しない。Homebrew は足した cask を入れるだけ):

```sh
sudo darwin-rebuild switch --flake ~/.config/nix-darwin#default
```

`casks` から消しても、アプリはアンインストールされない(`onActivation.cleanup = "none"`)。消したいときは手で:

```sh
brew uninstall --cask <名前>
```

全部を最新にする:

```sh
nix flake update --flake ~/.config/nix-darwin                   # nixpkgs / nix-darwin / SKK 辞書
sudo darwin-rebuild switch --flake ~/.config/nix-darwin#default
brew update && brew upgrade                                     # Homebrew の cask
mise upgrade                                                    # mise のツール
```

古い世代の掃除(Determinate Nix なので `nix.gc` は使えない)。1 週間より古い世代と、使われなくなったパッケージを消す
(今の世代は古くても消えない):

```sh
sudo nix-collect-garbage --delete-older-than 7d
```

Determinate Nix 自身の自動 GC(既定で有効)はディスクの空きが減ったときに使われていないパッケージを消すだけで、
古い世代は消さない。世代は 1 つあたり小さいので、気が向いたときに手で掃除すれば十分。

## 新しい Mac のセットアップ

1. `xcode-select --install`
2. Nix(Determinate):`curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
3. Homebrew:`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
4. このリポジトリを `~/.config/nix-darwin` に置く
5. 初回だけ:`sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/.config/nix-darwin#default`
   - ネットワークにつながり、画面にログインした状態で実行する(Docker 用の Lima VM のイメージをダウンロードするので数分かかる)
   - 終わったら、もう一度 `sudo darwin-rebuild switch --flake ~/.config/nix-darwin#default` する。
     macSKK の辞書を置くフォルダは macSKK が初めて起動したとき(1 回目の switch の最後)にできるので、辞書は 2 回目で置かれる
6. 新しいターミナルを開いて(Nix で入れたコマンドに PATH が通る)、dotfiles:
   ```sh
   git clone https://github.com/kenchan/dotfiles.git ~/src/github.com/kenchan/dotfiles
   cd ~/src/github.com/kenchan/dotfiles
   mise trust
   mise bootstrap                      # dotfiles のリンク、mise のツール、fish のプラグイン
   herdr integration install claude    # Claude Code の SessionStart フック(~/.claude/settings.json に書く)
   ```
   既にファイルがあってリンクできないと言われたら、中身を確かめてから `mise dotfiles apply --force`
7. 下の「手作業」をやる

## 手作業(Nix で管理していないもの)

### 入力ソースと macSKK の辞書
`darwin-rebuild switch` のときと、ログイン時(`launchd.user.agents.input-sources`)に `input-sources.js` が入力ソースを揃える
(`defaults` の `com.apple.HIToolbox` は安定して反映されないので、TIS の API を osascript から呼ぶ)。

- macSKK 本体と **ASCII** モードを有効にし、今の入力ソースが macSKK でなければ ASCII に切り替える
- ひらがななどのモードは入力ソースとしては有効にしない(macSKK の中で Ctrl+J などで切り替える)
- ABC は macOS の制約で消せないので残る
- 手作業: 「キーボードショートカット」→「入力ソース」の「前の入力ソースを選択」をオフにすると ABC に切り替わりにくい

macSKK の辞書は macSKK が初めて起動したときに作られるフォルダに置くので、新しい Mac では
初回の switch(ここで macSKK が有効になって起動する)のあとに、もう一度 switch すると配置・有効化される。

### git / gh
署名(1Password)と HTTPS の認証(`git-credential-gh`)は dotfiles 側で Mac にも対応しているので、`~/.config/git/config.local` は空でよい。
gh(Nix で入れている)に各アカウントでログインする:

```sh
gh auth login --hostname github.com --git-protocol https --web     # アカウントごとに
```

- 「Authenticate Git with your GitHub credentials?」は **n**(`Y` だと dotfiles の `~/.config/git/config` に書き込まれる)
- 同じホストに複数のアカウントがあるときは、リポジトリで `git config credential.username <アカウント>` を設定して選ぶ

### 1Password
- アプリは Nix / Homebrew では入れない。会社の Mac は MDM で入っていることがあり、cask にすると
  「もうアプリがある」で Homebrew が失敗して switch 全体が止まるため。入っていなければ公式サイトから入れる
  (CLI の `op` は Nix の `programs._1password` で入る)
- 「設定」→「開発者」で **1Password CLI と連携** をオン(`op vault list` で Touch ID が出れば OK)
- 同じ画面で **SSH エージェントを使用** をオン
- `~/.ssh/config`:
  ```sshconfig
  Host *
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  ```

### Herdr
- Herdr.app を起動すると herdr-core のインストールを案内される(`~/.local/bin/herdr-core` と `hc`)
- ログインシェルが fish なので、シェルの設定は要らない

### ログインシェル
switch のときに fish(`/run/current-system/sw/bin/fish`)にする。Ghostty、ターミナル.app、Herdr はこれで fish で開く。
Nix が壊れて fish が無くなると、ターミナルがすぐ閉じる(Mac の起動や GUI のログインには影響しない)。そのときは
「システム設定」→「ユーザとグループ」→ 自分を右クリック →「詳細オプション」でログインシェルを `/bin/zsh` に戻す。

### Docker(Lima の rootless Docker)
Mac 側は Nix の docker CLI(compose / buildx 付き)だけで、dockerd は Lima の VM で rootless で動かす。
`darwin-rebuild switch` のときに、VM(`docker`)と docker context(`lima-docker`)が無ければ作る(初回はイメージのダウンロードで数分かかる)。
VM はログイン時に `launchd.user.agents.lima-docker` が起動する(VM が無いときは何もしない)。

自動で作れなかったときは手で作る(作成が途中で失敗した VM が残っていると次の switch でも作り直されないので、先に消す):

```sh
limactl delete --force docker
limactl start --name=docker --mount-writable --tty=false template:docker
docker context create lima-docker --docker "host=unix://$HOME/.lima/docker/sock/docker.sock"
docker context use lima-docker
docker run --rm hello-world
```

- `template:docker` は rootless の dockerd(`docker info` の SecurityOptions に `name=rootless`)
- `--mount-writable` がないとホームが読み取り専用でマウントされ、bind mount に書けない
- Nix が面倒を見るのは「無ければ作る」まで。VM の設定(CPU やメモリなど)を変えたら作り直す
- 既存の VM を変えるときは `limactl stop docker && limactl edit --mount-writable docker && limactl start docker`
- VM の起動ログは `/tmp/lima-docker.log`

### ウィンドウの配置
macOS 標準のタイル機能を使う(自動で並べ直すタイル型ウィンドウマネージャーはウィンドウの開閉のたびに配置が動くので使わない)。
画面の端にドラッグする、緑のボタンにマウスを乗せる、または Control+Option+矢印キーで半分に、Control+Option+F で画面全体に寄せる。
既定の Fn+Control+矢印は Advantage360 では Fn が押せないので、switch のときにシステムのショートカット
(`com.apple.symbolichotkeys` の 237 と 240〜243、「キーボードショートカット」で変えられるものと同じ)を書き換えている。

### Kensington SlimBlade
- Kensington のサイトから公式アプリ(Kensington Konnect)を入れる。Homebrew にない
- アクセシビリティと入力監視を許可する

### ログイン項目
- 「システム設定」→「一般」→「ログイン項目と機能拡張」で、アプリ自身が登録した「ログイン時に開く」を整理する
- MDM が管理しているものは触らない
