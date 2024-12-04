#############################################################
#
#  Gusto - Home Theatre
#  NixOS running on ASUS VivoPC VM40B-S081M
#
###############################################################

{
  inputs,
  lib,
  configLib,
  ...
}:
{
  imports = lib.flatten [
    #################### Every Host Needs This ####################
    ./hardware-configuration.nix

    #################### Hardware Modules ####################
    inputs.hardware.nixosModules.common-cpu-intel
    #inputs.hardware.nixosModules.common-gpu-intel #This is apparently already declared in `/nix/store/HASH-source/common/gpu/intel

    #TODO move gusto to disko

    #################### Misc Inputs ####################
    inputs.stylix.nixosModules.stylix

    (map configLib.relativeToRoot [

      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      "hosts/common/optional/services/openssh.nix" # allow remote SSH access
      "hosts/common/optional/xfce.nix" # window manager until I get hyprland configured
      "hosts/common/optional/audio.nix" # pipewire and cli controls
      "hosts/common/optional/smbclient.nix" # mount the ghost mediashare
      "hosts/common/optional/vlc.nix" # media player

      #################### Users to Create ####################
      # ta imported via hosts/common/core
      "hosts/common/users/media"
    ])
  ];

  # Enable some basic X server options
  services.xserver.enable = true;
  services.xserver.displayManager = {
    lightdm.enable = true;
  };
  services.displayManager = {
    autoLogin.enable = true;
    autoLogin.user = "media";
  };

  networking = {
    hostName = "gusto";
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    timeout = 3;
  };

  boot.initrd = {
    systemd.enable = true;
  };

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
