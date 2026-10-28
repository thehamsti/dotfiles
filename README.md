# dotfiles

Personal macOS development environment configuration.

## What's Included

- **Shell**: ZSH with Oh My Zsh, plugins (autosuggestions, syntax highlighting, completions), and custom aliases
- **Package Management**: mise for runtimes and portable CLIs; Homebrew for native packages and desktop apps
- **Editor**: Neovim with AstroNvim configuration
- **Terminal workspace**: Herdr with personal keybindings, theme, and agent integrations
- **macOS**: Sensible system defaults (keyboard repeat, Finder settings, Dock config)
- **Development**: Node.js, Bun, Python, Ruby, Go, Java, .NET, and CLI tools via mise

## Prerequisites

- macOS (tested on Sonoma)
- Command Line Tools for Xcode: `xcode-select --install`
- Git (comes with Command Line Tools)

## Installation

1. Clone into your home directory:

```bash
git clone https://github.com/thehamsti/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. Run the setup script:

```bash
./setup_macos.sh
```

Setup refreshes sudo credentials throughout the run. Conflicting configs are
moved to unique `*.backup.*/original` locations before linking; repeating setup
keeps correct links in place. Touch ID settings use `sudo_local` with root-owned
permissions. The defaults script restarts Dock, Finder, and SystemUIServer.
Homebrew app installers can have their own update/restart requirements.

3. Restart your terminal (or `source ~/.zshrc`)

4. Open Neovim to install plugins:

```bash
nvim
```

## What the Setup Does

| Step | Script               | Description                                                         |
| ---- | -------------------- | ------------------------------------------------------------------- |
| 1    | `macos/macos.sh`     | Configure macOS defaults (Finder, Dock, keyboard)                   |
| 2    | `macos/brew.sh`      | Install Homebrew, native packages, and desktop apps                 |
| 3    | `macos/mise.sh`      | Link global mise config, install runtimes/CLIs, and add shell shims |
| 4    | `macos/setup_zsh.sh` | Install Oh My Zsh and plugins                                       |
|      | `macos/herdr.sh`     | Install Herdr, link config, add completions and agent integrations  |
| 5    | `macos/python.sh`    | Verify mise-managed Python and uv                                   |
| 6    | `macos/git.sh`       | Configure git defaults                                              |
| 7    | Symlink              | Link `~/.config/nvim` to neovim config                              |

Powerline is installed by mise in a private Python environment; tmux no longer
depends on a particular `~/Library/Python/<version>/bin` directory.

## Directory Structure

```
dotfiles/
├── setup_macos.sh          # Main setup script
├── mise.toml               # Global runtimes and CLI tools
├── herdr/
│   ├── config.toml         # Herdr theme, keybindings, UI, and worktree commands
│   └── integrations.txt    # Agent integrations to install
├── macos/
│   ├── Brewfile            # Homebrew packages (formulae + casks)
│   ├── aliases.sh          # Shell aliases and functions
│   ├── brew.sh             # Homebrew installation script
│   ├── git.sh              # Git configuration
│   ├── herdr.sh            # Herdr configuration and agent setup
│   ├── macos.sh            # macOS system preferences
│   ├── mise.sh             # Global mise installation and shell integration
│   ├── migrate_to_mise.sh  # Verify replacements and remove redundant Brew installs
│   ├── update.sh           # Unattended updates with one sudo login
│   ├── python.sh           # Verify Python and uv
│   └── setup_zsh.sh        # ZSH and Oh My Zsh setup
└── neovim/
    └── nvim/               # Neovim configuration (AstroNvim)
        ├── init.lua
        ├── lua/
        │   ├── community.lua
        │   ├── lazy_setup.lua
        │   └── plugins/
        └── ...
```

## Customization

### Adding Tools and Apps

Add runtimes and portable CLIs to `mise.toml`, then run `mise install --yes`.
`macos/mise.sh` links this file to `~/.config/mise/config.toml`, so the tools
are available outside this repository too. Project-specific mise configs still
select their own versions.

Mise setup also repairs GitHub credential helpers that still point at a
Homebrew `gh` binary. It uses the absolute mise shim path so desktop apps such
as T3 Code can authenticate without a shell-managed PATH.

Edit `macos/Brewfile` for native packages and desktop apps:

- Native packages: `brew "package-name"`
- GUI apps: `cask "app-name"`
- From taps: First add `tap "user/repo"`, then the package

Then run: `brew bundle --file=~/dotfiles/macos/Brewfile`

### Herdr

Herdr is installed through mise and updated by the existing `update` command.
To run just its setup after mise is installed:

```bash
bash ~/dotfiles/macos/herdr.sh
```

Setup validates and links `herdr/config.toml` to `~/.config/herdr/config.toml`.
It honors `HERDR_CONFIG_PATH`, `XDG_CONFIG_HOME`, and `ZDOTDIR`. Existing config
files are backed up before linking; session state, sockets, logs, and worktrees
stay in place. Setup adds Zsh completions and uses Herdr's native integration
installer to merge hooks into each agent's existing config.

The config preserves the Tokyo Night theme, `Ctrl+B` prefix, Alt/arrow navigation,
and your worktree shortcuts: `Prefix+Shift+W` creates a new branch from freshly
fetched `origin/main`. Enter cancels before fetching. Invalid names and existing
local branches are rejected; use Herdr's Open worktree action for existing branches.
The popup uses `HERDR_BIN_PATH` so it works without interactive shell PATH setup.
Creation uses the active pane's checkout and pins the fetched main commit.

`Prefix+Shift+K` closes a workspace and removes a clean linked checkout. Dirty
worktrees or invalid workspace metadata leave the workspace open.

`herdr/integrations.txt` records your 11 integrations: Pi, OMP, Claude Code,
Codex, Droid, Kimi, OpenCode, Hermes, Cursor, Antigravity CLI, and Grok.
Edit this list to change which integrations setup installs. Agents that have not
created their config directories yet are skipped with a message. Install and
run those agents first, then repeat Herdr setup to add their hooks. Repeating
setup refreshes hooks without replacing unrelated agent settings; other
integration failures are reported with a nonzero exit code.

Setup and package updates keep running Herdr sessions open. The older direct
install in `~/.local/bin/herdr` is left available for processes that still use it;
new shells use the mise shim. No launch agent is needed: Herdr manages its own
persistent server. See the [Herdr installation docs](https://herdr.dev/docs/install/)
and [agent integration docs](https://herdr.dev/docs/integrations/).

### Adding Aliases

Edit `macos/aliases.sh`, then run `reload` in the current terminal.
Reload checks `.zshrc` syntax before sourcing it, honors `ZDOTDIR`, keeps search
paths and shell hooks unique, reapplies dotfile aliases after Atuin, and refreshes
command lookup. It preserves the current shell, working directory, and variables.
Runtime errors inside `.zshrc` are reported by their commands; reload cannot undo
startup commands that already ran.

### Shared Agent Skills

`pr-ready` creates or reuses a non-draft GitHub PR and keeps addressing CI and
Greptile/Cursor feedback until the current commit passes and reviews settle.
It fixes valid findings, pushes validated changes, explains disputed findings,
and resolves handled bot threads. When Greptile reviews the PR, it requires a
verifiable score of at least **4/5** on the current head and requests re-review
with a PR comment containing `@greptileai`. Completion requires a five-minute
quiet window and two live observations at least 60 seconds apart. It leaves the
PR open and unmerged.

The source is [agents/skills/pr-ready/SKILL.md](agents/skills/pr-ready/SKILL.md).
macOS setup links it into Codex, Claude Code (default, personal, and work), Grok,
Cursor, OpenCode, and Pi. Install or refresh just these links with:

```bash
bash ~/dotfiles/macos/skills.sh
```

Start a new agent session after installing it. Use `$pr-ready` in Codex,
`/pr-ready` in Claude Code, Cursor, or Grok, `/skill:pr-ready` in Pi, or ask any of the
agents to "Use the pr-ready skill for this repository." Git and authenticated
GitHub CLI access are required. Invoking the workflow authorizes its PR, commit,
push, bot-reply, re-review, and thread-resolution steps; creating/installing the
skill does not start that workflow.

### Zsh Startup

Setup optimizes existing `.zshrc` files with `macos/configure_zsh.ts`. To apply
only these changes after Bun is installed:

```bash
bun ~/dotfiles/macos/configure_zsh.ts "${ZDOTDIR:-$HOME}/.zshrc"
```

It saves a private backup beside `.zshrc`, checks the result with `zsh -n`, and
preserves custom settings. Repeating it leaves an already configured file alone.

The startup helpers keep paths and hooks unique, make Docker completions visible
before Oh My Zsh initializes completion, and remove Docker's duplicate `compinit`.
Completion security checks remain enabled. The unused default Oh My Zsh theme
is disabled when Starship is configured, and repeated Bun installer blocks are
collapsed into one.

Mise selects Node normally. NVM stays available through `nvm`, which loads it and
its completions on first use without automatically switching Node. Codex's native
completions are generated on the first Tab press for Codex in each shell instead
of during startup. The first completion may therefore take slightly longer.

### Neovim Plugins

- Community plugins: Edit `neovim/nvim/lua/community.lua`
- Custom plugins: Add files to `neovim/nvim/lua/plugins/`

## Key Aliases

| Alias       | Command                                 |
| ----------- | --------------------------------------- |
| `ll`        | List files with details (eza)           |
| `lt`        | Tree view of directories                |
| `gs`        | `git status`                            |
| `gp`        | `git push`                              |
| `gpu`       | `git pull`                              |
| `d`         | `docker`                                |
| `dc`        | `docker compose`                        |
| `v` / `vim` | `nvim`                                  |
| `cd`        | `z` (zoxide)                            |
| `reload`    | Reload and validate shell configuration |

See `macos/aliases.sh` for the full list.

## Manual Steps

Some things can't be automated:

1. **ZSH plugins**: Add to your `~/.zshrc` plugins line:

   ```
   plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
   ```

2. **macOS settings**: Some changes require logout/restart to take effect

3. **App-specific settings**: Sign into apps, configure preferences manually

## Updating

```bash
cd ~/dotfiles
git pull

# Update global mise tools, remaining Homebrew packages/apps, Bun globals, and macOS
update

# Package updates without macOS updates or the initial sudo login
update --no-system

# Scheduled run: never prompt; reports failure if sudo is unavailable
bash ~/dotfiles/macos/update.sh --non-interactive

# Preview commands without making changes
update --dry-run

# Update Neovim plugins (inside nvim)
:Lazy update
```

`update` authenticates once, keeps the sudo session alive, accepts package-manager
confirmations, and reports failed steps at the end. It does not run the legacy
Nix rebuild. It updates global mise tools without changing project version pins
and preserves runtime release ranges. Homebrew updates mise itself.

Homebrew runs first so mise itself is current before plugin/tool upgrades.
Setup and updates install the complete gcloud plugin from its upstream Git
repository, which includes the Python-discovery helper omitted from mise's
embedded copy in the affected release. Plugin updates finish before tool
upgrades and shim regeneration; failures are reported instead of continuing
with a broken plugin.

The suggestion to run `mise outdated --bump` is informational: newer releases
outside a configured version range are available. The normal `update` command
keeps those ranges; it does not automatically switch runtime release lines.

Global Bun package updates explicitly select `bun@latest`, so an inherited
`MISE_BUN_VERSION` from a project cannot select an older Bun runtime.
If Atuin manages your aliases, point its stored alias at the same script:

```sh
atuin dotfiles alias set update 'bash ~/dotfiles/macos/update.sh'
atuin dotfiles alias set reload 'source ~/dotfiles/macos/reload.zsh'
```

macOS updates agree to the license and never request an automatic restart. On
Apple Silicon, updates requiring separate owner authentication may need System
Settings. In `--no-system` mode, apps requiring uncached administrator privileges
fail without opening a password dialog. App failures are reported, not hidden.

For another machine with existing Homebrew packages:

```bash
bash ~/dotfiles/macos/migrate_to_mise.sh
bash ~/dotfiles/macos/migrate_to_mise.sh --remove-homebrew
```

The migration checks every replacement before uninstalling anything, saves a
Homebrew restore inventory under `~/.local/state/dotfiles/homebrew-to-mise/`, and
retains formulae required by other Homebrew packages. It does not remove native
libraries, database data, or desktop apps. See [the package review](macos/homebrew-review.md)
for the audit and retained packages. The `nix/` directory is a legacy setup;
explicit Nix aliases remain available separately.

Run all dotfile tests with `bun test`. Tests use temporary homes and mocked
package installers/privileged commands. See [the macOS review](macos/review-2026-10-26.md)
for findings, validation limits, and legacy PAM/preference repair commands.

## Backups

Run `./backup.sh` to save a private snapshot under `~/dotfiles-backup-*`.
It includes the global mise config, runtime inventory, Bun package manifest, Herdr config,
Zsh login and interactive config, Git/SSH config, and selected app settings.
Failed exports are reported after the remaining backup completes, with a
nonzero exit code. SSH private keys and GitHub CLI credential-store files are
excluded; saved shell/Git configs can contain inline secrets.

## Troubleshooting

**`ls`/eza reports a missing Homebrew libgit2 dylib**: Older Cargo builds could
link eza to Homebrew's libgit2. The mise config now enables `vendored-libgit2`
so the library is bundled into eza. Rebuild an older installation with:

```bash
mise -C ~/dotfiles install --yes --force cargo:eza
```

This keeps eza's Git support without depending on Homebrew's libgit2 installation.

**Starship Git timeout when opening a shell**: Git setup keeps FSMonitor off
globally because its read-only status queries can stall past Starship's timeout
on macOS. To repair an older setup, run:

```bash
git config --global core.fsmonitor false
```

This keeps Git status indicators in the prompt. Repositories can opt in with
`git config --local core.fsmonitor true` if their FSMonitor performs well.

**Homebrew not found after install**: On Apple Silicon, add to `~/.zshrc`:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Neovim plugins not loading**: Run `:Lazy sync` inside Neovim

**ZSH plugins not working**: Ensure plugins are in the `plugins=(...)` line in `~/.zshrc`
