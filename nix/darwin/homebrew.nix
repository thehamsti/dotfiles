{ ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    taps = [
      "jesseduffield/lazygit"
      "localstack/tap"
      "oven-sh/bun"
      "sst/tap"
      "stripe/stripe-cli"
      "supabase/tap"
      "ubuntu/microk8s"
    ];

    brews = [
      # Cloud & Infrastructure
      "aws-elasticbeanstalk"
      "aws-sam-cli"
      "doctl"
      "sst/tap/sst"
      "localstack/tap/localstack-cli"
      "stripe/stripe-cli/stripe"
      "supabase/tap/supabase"
      "ubuntu/microk8s/microk8s"

      # Database
      "postgresql@15"

      # Ruby
      "rbenv-default-gems"
      "rbenv-gemset"

      # iOS Development
      "cocoapods"

      # AI/ML
      "livekit"
      "portaudio"

      # Development - Languages & Runtimes (brew-specific)
      "dotnet"
      "dotnet@8"
      "llvm@17"
    ];

    casks = [
      # Terminals & Editors
      "ghostty"
      "wezterm"
      "zed"
      "sublime-text"

      # Development
      "orbstack"
      "bruno"
      "multipass"

      # Productivity
      "alfred"
      "rectangle"
      "jordanbaird-ice"
      "caffeine"
      "dropbox"
      "nextcloud"

      # Utilities
      "stats"
      "flux-app"
      "superduper"

      # Media
      "vlc"
      "transmission"

      # Academic
      "mactex"
      "zotero"

      # Misc
      "1password-cli"
    ];
  };
}
