{
  lib,
  pkgs,
  configLib,
  configVars,
  ...
}:
let
  sshPort = configVars.networking.ports.tcp.ssh;
in
{
  imports = [ (configLib.relativeToRoot "hosts/common/users/${configVars.username}") ];

  fileSystems."/boot".options = [ "umask=0077" ]; # Removes permissions and security warnings.
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot = {
    enable = true;
    # we use Git for version control, so we don't need to keep too many generations.
    configurationLimit = lib.mkDefault 3;
    # pick the highest resolution for systemd-boot's console.
    consoleMode = lib.mkDefault "max";
  };
  boot.initrd.systemd.enable = true;

  networking = {
    # configures the network interface(include wireless) via `nmcli` & `nmtui`
    networkmanager.enable = true;
  };

  services = {
    qemuGuest.enable = true;
    openssh = {
      enable = true;
      ports = [ sshPort ];
      settings.PermitRootLogin = "yes";
    };
  };

  # allow sudo over ssh with yubikey
  security.pam = {
    sshAgentAuth.enable = true;
    services.sudo = {
      u2fAuth = true;
      sshAgentAuth = true;
    };
  };

  environment.systemPackages = builtins.attrValues { inherit (pkgs) wget curl rsync; };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };
  system.stateVersion = "23.11";
}
