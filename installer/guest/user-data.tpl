#cloud-config
# WoW-Mac – Grundsystem der Linux-VM (Ubuntu 26.04 arm64 in UTM/QEMU).
# Die Platzhalter (Grossbuchstaben zwischen doppelten Unterstrichen) fuellt der Installer auf dem Mac aus.
hostname: wow-linux
locale: __LOCALE__
timezone: __TZ__
keyboard:
  layout: __XKB_LAYOUT__
  variant: __XKB_VARIANT__
  model: pc105
  options: lv3:ralt_switch
users:
  - name: __USER__
    uid: __UID__
    gecos: WoW
    groups: [adm, audio, video, render, input, sudo, plugdev]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
growpart:
  mode: auto
  devices: ["/"]
resize_rootfs: true
bootcmd:
  # Spielordner des Macs (VirtFS-Freigabe "share") einhaengen
  - [sh, -c, "mkdir -p /mnt/wow && (mountpoint -q /mnt/wow || mount -t 9p -o trans=virtio,version=9p2000.L,msize=524288,cache=mmap share /mnt/wow) || true"]
  # Gastagent frueh installieren, damit der Mac den Fortschritt lesen kann. Vorher die Systempartition
  # vergroessern – cloud-init macht das sonst erst nach bootcmd, und fuer apt ist sie anfangs zu klein.
  - |
    if [ ! -x /usr/sbin/qemu-ga ]; then
      R=$(findmnt -n -o SOURCE /)
      P=$(basename "$R")
      D=$(lsblk -no PKNAME "$R" 2>/dev/null)
      N=$(cat "/sys/class/block/$P/partition" 2>/dev/null)
      if [ -n "$D" ] && [ -n "$N" ]; then growpart "/dev/$D" "$N" && resize2fs "$R"; fi
      apt-get -q update && DEBIAN_FRONTEND=noninteractive apt-get -q -y install qemu-guest-agent
    fi
    systemctl start --no-block qemu-guest-agent || true
mounts:
  - [share, /mnt/wow, 9p, "trans=virtio,version=9p2000.L,msize=524288,cache=mmap,rw,nofail", "0", "0"]
package_update: true
package_upgrade: true
packages:
  - linux-generic
  - qemu-guest-agent
  - xfce4
  - xfce4-terminal
  - lightdm
  - lightdm-gtk-greeter
  - xserver-xorg
  - x11-xserver-utils
  - x11-utils
  - dbus-x11
  - spice-vdagent
  - mesa-utils
  - mesa-vulkan-drivers
  - pipewire-audio
  - wireplumber
  - pavucontrol
  - alsa-utils
  - icoutils
  - curl
  - cabextract
  - unzip
  - htop
  - fonts-dejavu
__LANGPACK__
write_files:
  - path: /etc/wow-mac.conf
    permissions: "0644"
    content: |
      # WoW-Mac – Einstellungen der VM (vom Installer erzeugt)
      WOW_USER=__USER__
      WINE_KBD=__WINE_KBD__
      HANGOVER_VERSION=__HANGOVER_VERSION__
      HANGOVER_SHA256=__HANGOVER_SHA256__
      WOWMAC_VERSION=__WOWMAC_VERSION__
  - path: /usr/local/sbin/wow-provision
    permissions: "0755"
    encoding: b64
    content: __B64_PROVISION__
  - path: /usr/local/bin/wow-start
    permissions: "0755"
    encoding: b64
    content: __B64_START__
  - path: /usr/local/bin/wow-launch
    permissions: "0755"
    encoding: b64
    content: __B64_LAUNCH__
runcmd:
  - [/usr/local/sbin/wow-provision]
