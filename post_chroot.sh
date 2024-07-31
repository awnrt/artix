ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

mkdir -p /etc/modprobe.d/
echo "options hid_apple fnmode=0" > /etc/modprobe.d/hid_apple.conf
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

pacman -S dhcpcd dhcpcd-runit --noconfirm
ln -s /etc/runit/sv/dhcpcd /etc/runit/runsvdir/default

SMFSUWER=$(blkid -s PARTUUID -o value /dev/$root_drive)
POWERSMFSUWER='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet options root=PARTUUID='$SMFSUWER' rw nvidia-drm.modeset=1 modeset=1 fbdev=1 intel_iommu=on"'
sed -i "s/GRUB_CMDLINE_LINUX_DEF\(.*\)/$POWERSMFSUWER/g" /etc/default/grub

pacman -S linux-zen-headers --noconfirm
pacman -S nvidia-open-dkms intel-ucode trizen grub os-prober efibootmgr --noconfirm
sed -i -e 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

rm /post_chroot.sh
