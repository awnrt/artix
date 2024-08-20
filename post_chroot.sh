ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

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

echo $_hostname > /etc/hostname
PARTUUID_ROOT=$(blkid -s PARTUUID -o value /dev/$root_drive)

if [ "$_kernelflag" -eq 1 ]; then
  echo "options hid_apple fnmode=0" > /etc/modprobe.d/hid_apple.conf
  pacman -S grub os-prober efibootmgr --noconfirm  
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
  GRUB_MODIFIED_LINE='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet options root=PARTUUID='$PARTUUID_ROOT' rw nvidia-drm.modeset=1 modeset=1 fbdev=1 intel_iommu=on"'
  sed -i "s/GRUB_CMDLINE_LINUX_DEF\(.*\)/$GRUB_MODIFIED_LINE/g" /etc/default/grub
  pacman -S linux-zen-headers --noconfirm
  sed -i -e 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
elif [ "$_kernelflag" -eq 2 ]; then
  pacman -S efibootmgr --noconfirm
  cd /usr/src/
  curl -LO "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.6.tar.xz"
  tar -xf "linux-6.10.6.tar.xz"
  rm -f "linux-6.10.6.tar.xz"
  mv "linux-6.10.6" "linux"
  cd "linux"
  curl -LO "https://codeberg.org/awy/artix/raw/branch/minimal/.config"
  sed -i -e '/^CONFIG_CMDLINE="root=PARTUUID=.*/c\' -e "CONFIG_CMDLINE=\"root=PARTUUID=$PARTUUID_ROOT init=/sbin/openrc-init nvidia_drm.modeset=1 nvidia_drm.fbdev=1 intel_iommu=on\"" .config
  pacman -S bc perl bison make diffutils gcc flex rsync --noconfirm
  make oldconfig
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
else
  printf ${LIGHTRED}"Wrong kernelflag value.${NoColor}\n"
  exit 1
fi

useradd -m -g users -G wheel,storage,power -s /bin/bash $_username

echo root:$_rootpasswd | chpasswd
echo $_username:$_userpasswd | chpasswd

pacman -Sy --noconfirm
pacman -S artix-archlinux-support --noconfirm
echo "[extra]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
pacman -Sy --noconfirm

pacman -S doas --noconfirm
cat <<EOL >> /etc/doas.conf
permit nopass :wheel
permit nopass keepenv :$_username
permit nopass keepenv :root
EOL

pacman -S dhcpcd dhcpcd-openrc --noconfirm
rc-update add dhcpcd default

pacman -S nvidia-open-dkms --noconfirm

if [ "$_kernelflag" -eq 1 ]; then
  grub-mkconfig -o /boot/grub/grub.cfg
fi

# use dash as sh
pacman -Sy dash
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

rm /post_chroot.sh
