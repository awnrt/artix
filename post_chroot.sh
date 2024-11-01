#!/bin/bash
set -e

ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# different nvidia fixes
mkdir -p /etc/modprobe.d/
cat <<EOL >> /etc/modprobe.d/nvidia.conf
options nvidia NVreg_UsePageAttributeTable=1
options nvidia-drm fbdev=1
options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"
EOL

sed -i -e "/^#"en_US.UTF-8"/s/^#//" /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG="en_US.UTF-8"
export LC_COLLATE="C"

echo $hostname > /etc/hostname
PARTUUID_ROOT=$(blkid -s PARTUUID -o value /dev/$root_drive)

binKernel(){
  echo "options hid_apple fnmode=0" > /etc/modprobe.d/hid_apple.conf
  pacman -S grub os-prober efibootmgr --noconfirm  
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
  GRUB_MODIFIED_LINE='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet options root=PARTUUID='$PARTUUID_ROOT' rw nvidia-drm.modeset=1 modeset=1 fbdev=1 intel_iommu=on"'
  sed -i "s/GRUB_CMDLINE_LINUX_DEF\(.*\)/$GRUB_MODIFIED_LINE/g" /etc/default/grub
  sed -i -e 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
  if [ "$choosenKernel" -eq 1 ]; then
    pacman -S linux-headers --noconfirm
  elif [ "$choosenKernel" -eq 2 ]; then
    pacman -S linux-zen-headers --noconfirm
  else
    printf "Wrong kernelflag value.\n"
    exit 1
  fi
}

customKernel(){
  latestKernel=$(curl -s https://www.kernel.org/ | grep -A 1 'latest_link' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
  majorVersion=$(echo $latestKernel | cut -d'.' -f1)
  pacman -S efibootmgr --noconfirm
  cd /usr/src/
  curl -Lo /usr/src/linux.tar.xz "https://cdn.kernel.org/pub/linux/kernel/v$majorVersion.x/linux-$latestKernel.tar.xz"
  tar -xf "linux.tar.xz"
  rm -f "linux.tar.xz"
  mv "linux-$latestKernel" "linux"
  cd "linux"
  mv /usr/src/.config .config
  sed -i -e '/^CONFIG_CMDLINE="root=PARTUUID=.*/c\' -e "CONFIG_CMDLINE=\"root=PARTUUID=$PARTUUID_ROOT init=/sbin/dinit-init nvidia_drm.modeset=1 nvidia_drm.fbdev=1\"" .config
  pacman -S bc perl bison make diffutils gcc flex rsync --noconfirm
  make olddefconfig
  make menuconfig
  make -j$(nproc)
  make modules
  make modules_install
  make headers
  make headers_install
  mkdir -p /boot/EFI/BOOT
  cp arch/x86/boot/bzImage /boot/EFI/BOOT/BOOTX64.EFI
  _diskdrivewop="${disk_drive%p}"
  efibootmgr -c -d /dev/$_diskdrivewop -p $_numBoot -L "linux" -l '\EFI\BOOT\BOOTX64.EFI'
}

case $choosenKernel in
  1) binKernel && grub-mkconfig -o /boot/grub/grub.cfg ;;
  2) binKernel && grub-mkconfig -o /boot/grub/grub.cfg ;;
  3) customKernel ;;
esac

# use dash as sh
pacman -Sy dash zsh --noconfirm
ln -sfT dash /usr/bin/sh
mkdir -p /etc/pacman.d/hooks
cat <<EOL >> /etc/pacman.d/hooks/bash.hook
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = bash

[Action]
Description = Re-pointing /bin/sh symlink to dash...
When = PostTransaction
Exec = /usr/bin/ln -sfT dash /usr/bin/sh
Depends = dash
EOL

useradd -m -g users -G wheel,storage,power -s /bin/zsh $username

echo root:$rootpass | chpasswd
echo $username:$userpass | chpasswd

cat <<EOL >> /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $hostname.localdomain $hostname
EOL

# enable arch repos
pacman -Sy --noconfirm
pacman -S artix-archlinux-support --noconfirm
echo "[extra]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
pacman -Sy --noconfirm

pacman -S doas --noconfirm
cat <<EOL >> /etc/doas.conf
permit nopass :wheel
permit nopass keepenv :$username
permit nopass keepenv :root
EOL

pacman -S dhcpcd dhcpcd-dinit dbus-dinit --noconfirm
ln -sf /etc/dinit.d/dhcpcd /etc/dinit.d/boot.d/
ln -sf /etc/dinit.d/dbus /etc/dinit.d/boot.d/

pacman -S nvidia-open-dkms nvidia-utils --noconfirm

rm /post_chroot.sh
