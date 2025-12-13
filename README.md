# dotfiles

Personal macOS development environment configuration.

## What's Included

- **Shell**: ZSH with Oh My Zsh, plugins (autosuggestions, syntax highlighting, completions), and custom aliases
- **Package Management**: Homebrew with organized Brewfile
- **Editor**: Neovim with AstroNvim configuration
- **macOS**: Sensible system defaults (keyboard repeat, Finder settings, Dock config)
- **Development**: Python (via uv), Node.js (via fnm), and various CLI tools

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

3. Restart your terminal (or `source ~/.zshrc`)

4. Open Neovim to install plugins:

```bash
nvim
```

## What the Setup Does

| Step | Script | Description |
|------|--------|-------------|
| 1 | `macos/macos.sh` | Configure macOS defaults (Finder, Dock, keyboard) |
| 2 | `macos/setup_zsh.sh` | Install Oh My Zsh and plugins |
| 3 | `macos/brew.sh` | Install Homebrew and packages from Brewfile |
| 4 | `macos/python.sh` | Install Python versions via uv |
| 5 | `macos/git.sh` | Configure git defaults |
| 6 | Symlink | Link `~/.config/nvim` to neovim config |

## Directory Structure

```
dotfiles/
├── setup_macos.sh          # Main setup script
├── macos/
│   ├── Brewfile            # Homebrew packages (formulae + casks)
│   ├── aliases.sh          # Shell aliases and functions
│   ├── brew.sh             # Homebrew installation script
│   ├── git.sh              # Git configuration
│   ├── macos.sh            # macOS system preferences
│   ├── python.sh           # Python setup via uv
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

### Adding Homebrew Packages

Edit `macos/Brewfile` and add:
- CLI tools: `brew "package-name"`
- GUI apps: `cask "app-name"`
- From taps: First add `tap "user/repo"`, then the package

Then run: `brew bundle --file=~/dotfiles/macos/Brewfile`

### Adding Aliases

Edit `macos/aliases.sh` - changes take effect after `source ~/.zshrc` or opening a new terminal.

### Neovim Plugins

- Community plugins: Edit `neovim/nvim/lua/community.lua`
- Custom plugins: Add files to `neovim/nvim/lua/plugins/`

## Key Aliases

| Alias | Command |
|-------|---------|
| `ll` | List files with details (eza) |
| `lt` | Tree view of directories |
| `gs` | `git status` |
| `gp` | `git push` |
| `gpu` | `git pull` |
| `d` | `docker` |
| `dc` | `docker compose` |
| `v` / `vim` | `nvim` |
| `cd` | `z` (zoxide) |
| `reload` | `source ~/.zshrc` |

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

# Update Homebrew packages
brew bundle --file=~/dotfiles/macos/Brewfile

# Update Neovim plugins (inside nvim)
:Lazy update
```

## Troubleshooting

**Homebrew not found after install**: On Apple Silicon, add to `~/.zshrc`:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Neovim plugins not loading**: Run `:Lazy sync` inside Neovim

**ZSH plugins not working**: Ensure plugins are in the `plugins=(...)` line in `~/.zshrc`
