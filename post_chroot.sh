pacman -Sy bash-completion --noconfirm
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen

echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG="en_US.UTF-8"
export LC_COLLATE="C"

pacman -S grub os-prober efibootmgr --noconfirm

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub

grub-mkconfig -o /boot/grub/grub.cfg

useradd -m -g users -G wheel,storage,power -s /bin/bash $_username

echo root:$_rootpasswd | chpasswd

echo $_username:$_userpasswd | chpasswd

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
echo "Defaults rootpw" >> /etc/sudoers

echo $_hostname > /etc/hostname

echo "[lib32]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Sy --noconfirm

pacman -S dhcpcd connman-openrc --noconfirm
rc-update add connmand

pacman -S intel-ucode --noconfirm

SMFSUWER=$(blkid -s PARTUUID -o value /dev/$root_drive)
POWERSMFSUWER='GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet options root='$SMFSUWER' rw nvidia-drm.modeset=1 intel_iommu=on"'
sed -i "s/GRUB_CMDLINE_LINUX_DEF\(.*\)/$POWERSMFSUWER/g" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

pacman -S linux-headers --noconfirm
pacman -S trizen --noconfirm
pacman -S nvidia-dkms nvidia-utils opencl-nvidia lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings libxnvctrl  --noconfirm

#trizen -S nvidia-535xx-utils nvidia-535xx-dkms opencl-nvidia-535xx lib32-opencl-nvidia-535xx lib32-nvidia-535xx-utils nvidia-535xx-settings libxnvctrl-535xx


sudo sed -i -e 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf


mkdir /etc/pacman.d/hooks
echo "[Trigger]" >> /etc/pacman.d/hooks/nvidia
echo "Operation=Install" >> /etc/pacman.d/hooks/nvidia
echo "Operation=Upgrade" >> /etc/pacman.d/hooks/nvidia
echo "Operation=Remove" >> /etc/pacman.d/hooks/nvidia
echo "Type=Package" >> /etc/pacman.d/hooks/nvidia
echo "Target=nvidia" >> /etc/pacman.d/hooks/nvidia
echo "[Action]" >> /etc/pacman.d/hooks/nvidia
echo "Depends=mkinitcpio" >> /etc/pacman.d/hooks/nvidia
echo "When=PostTransaction" >> /etc/pacman.d/hooks/nvidia
echo "Exec=/usr/bin/mkinitcpio -P" >> /etc/pacman.d/hooks/nvidia

rm /post_chroot.sh
