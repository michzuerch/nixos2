{
  pkgs,
  inputs,
  config,
  lib,
  configVars,
  configLib,
  ...
}:
let
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
  sopsHashedPasswordFile =
    lib.optionalString (lib.hasAttr "sops-nix" inputs)
      config.sops.secrets."passwords/${configVars.username}".path;
  pubKeys = lib.filesystem.listFilesRecursive ./keys;

  # these are values we don't want to set if the environment is minimal. E.g. ISO or nixos-installer
  # isMinimal is true in the nixos-installer/flake.nix
  fullUserConfig = lib.optionalAttrs (!configVars.isMinimal) {
    users.users.${configVars.username} = {
      hashedPasswordFile = sopsHashedPasswordFile;
      packages = [ pkgs.home-manager ];
    };

    # Import this user's personal/home configurations
    home-manager.users.${configVars.username} = import (
      configLib.relativeToRoot "home/${configVars.username}/${config.networking.hostName}.nix"
    );
  };
in
{
  config =
    lib.recursiveUpdate fullUserConfig
      #this is the second argument to recursiveUpdate
      {
        users.mutableUsers = false; # Only allow declarative credentials; Required for sops
        users.users.${configVars.username} = {
          home = "/home/${configVars.username}";
          isNormalUser = true;
          password = "nixos"; # Overridden if sops is working

          extraGroups =
            [ "wheel" ]
            ++ ifTheyExist [
              "audio"
              "video"
              "docker"
              "git"
              "networkmanager"
              "scanner" # for print/scan"
              "lp" # for print/scan"
            ];

          # These get placed into /etc/ssh/authorized_keys.d/<name> on nixos
          openssh.authorizedKeys.keys = lib.lists.forEach pubKeys (key: builtins.readFile key);

          shell = pkgs.zsh; # default shell
        };

        # Proper root user required for borg and some other specific operations
        users.users.root = {
          shell = pkgs.zsh;
          hashedPasswordFile = config.users.users.${configVars.username}.hashedPasswordFile;
          password = lib.mkForce config.users.users.${configVars.username}.password;
          # root's ssh keys are mainly used for remote deployment.
          openssh.authorizedKeys.keys = config.users.users.${configVars.username}.openssh.authorizedKeys.keys;
        };
        # Setup p10k.zsh for root
        home-manager.users.root = lib.optionalAttrs (!configVars.isMinimal) {
          home.stateVersion = "23.05"; # Avoid error
          programs.zsh = {
            enable = true;
            plugins = [
              {
                name = "powerlevel10k-config";
                src = configLib.relativeToRoot "home/${configVars.username}/common/core/zsh/p10k";
                file = "p10k.zsh";
              }
            ];
          };
        };

        # create ssh sockets directory for controlpaths when homemanager not loaded (i.e. isminimal)
        systemd.tmpfiles.rules =
          let
            user = config.users.users.${configVars.username}.name;
            group = config.users.users.${configVars.username}.group;
          in
          [ "d /home/${configVars.username}/.ssh/sockets 0750 ${user} ${group} -" ];

        # No matter what environment we are in we want these tools for root, and the user(s)
        programs.zsh.enable = true;
        programs.git.enable = true;
        environment.systemPackages = [
          pkgs.just
          pkgs.rsync
        ];
      };
}
