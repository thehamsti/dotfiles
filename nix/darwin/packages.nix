{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Core utilities
    git
    wget
    jq
    yq
    ripgrep
    fd
    eza
    bat
    tree
    fzf
    zoxide

    # Git tools
    gh
    lazygit
    diff-so-fancy
    delta

    # System monitoring
    btop
    htop
    ncdu
    speedtest-cli
    fping

    # Networking / VPN
    wireguard-tools
    wireguard-go

    # Development - Languages & Runtimes
    mise
    deno
    go
    uv
    ruff
    pipx
    gcc
    cmake
    protobuf
    scala
    sbt

    # Development - Tools
    neovim
    helix
    tmux
    ranger
    act
    watchman

    # Cloud
    awscli2

    # Database
    postgresql_17

    # Media & Files
    ffmpeg
    sox
    graphviz
    gdrive

    # AI/ML
    ollama
    llama-cpp

    # Package managers
    pnpm
    yarn

    # Shell enhancements
    starship
    direnv

    # Misc CLI
    fastfetch

    # Libraries
    gdbm
    libev
    mvfst
  ];
}
