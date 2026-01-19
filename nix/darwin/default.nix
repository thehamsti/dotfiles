{ username, hostname, ... }:
{
  imports = [
    ./packages.nix
    ./homebrew.nix
  ];

  # Determinate Nix manages the daemon, so disable nix-darwin's nix management
  nix.enable = false;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Required for homebrew and other user-specific options
  system.primaryUser = username;

  networking.hostName = hostname;

  programs.zsh.enable = true;

  system.configurationRevision = null;
  system.stateVersion = 4;
}
