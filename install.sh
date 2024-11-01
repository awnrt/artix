#!/bin/bash
set -e
export red="\033[1;31m"
export green="\033[1;32m"
export cyan="\033[0;36m"
export normal="\033[0m"

dinitctl start ntpd

cpuVendorID=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

title() {
    clear
    echo -ne "${cyan}
################################################################################
#                                                                              #
#                 This is Automated Artix Linux Installer                      #
#                                                                              #
#                                     By                                       #
#                                                                              #
#                                   awy :)                                       #
#                                                                              #
################################################################################
${normal}
"
}

diskpart(){
  mkfs.fat -F32 /dev/"$boot_drive"
  mkfs.ext4 -F /dev/"$root_drive"
  mount /dev/"$root_drive" /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
}

binKernel(){
  mkdir /mnt/boot/efi
  mount /dev/"$boot_drive" /mnt/boot/efi
  pacman -Sy --confirm
  if [ "$choosenKernel" -eq 1 ]; then
    basestrap /mnt base dinit seatd-dinit linux linux-headers
  elif [ "$choosenKernel" -eq 2 ]; then
    basestrap /mnt base dinit seatd-dinit linux-zen linux-zen-headers
  else
    printf "Wrong kernelflag value.\n"
    exit 1
  fi
}

customKernel(){
  mount /dev/$boot_drive /mnt/boot
  pacman -Sy --confirm
  basestrap /mnt base dinit seatd-dinit udev 
  cp .config /mnt/usr/src
}

getUserData(){
  read -srp "Enter root password: " rootpass
  echo
  read -rp "Enter username: " username
  read -srp "Enter password for $username: " userpass
  echo
  read -rp "Enter hostname: " hostname
  printf ${red}"Choose Linux Kernel:${normal}\n1. Default kernel\n2. Zen kernel\n3. Custom kernel${normal}\nYour choose: "
  read -r choosenKernel
  read -rp "Enter disk label (e.g. sda, nvme0n1p <- p is mandatory in nvme case): " disk_drive
  read -rp "Enter comma-separated partition numbers (e.g., 5,6 for 5 boot 6 root): " partitions
  IFS=',' read -r -a partition_array <<< "$partitions"
  root_drive="$disk_drive${partition_array[1]}"
  boot_drive="$disk_drive${partition_array[0]}"
  while true; do
    clear
    title
    printf ${normal}"Your CPU Vendor detected as ${green}$cpuVendorID${normal}, is that right? Y/N:\n"
    read -r answer
    case "$answer" in
      y|Y)
        break ;;
      n|N)
        echo "Something wrong. Exiting..."
        exit 1 ;;
      *)
        echo "Invalid response. Please enter 'y' or 'n'." && sleep 3 ;;
    esac
  done
}

title
getUserData
diskpart

case $choosenKernel in
  1) binKernel ;;
  2) binKernel ;;
  3) customKernel ;;
esac

case $cpuVendorID in
  GenuineIntel)
    basestrap /mnt intel-ucode
    if [ "$choosenKernel" -eq 3 ]; then
      pacman -S iucode-tool --noconfirm
      CPUFAM=$(printf '%02x\n' $(lscpu | grep -E '^CPU family:' | awk '{print $3}'))
      MODEL=$(printf '%02x\n' $(lscpu | grep -E '^Model:' | awk '{print $2}'))
      STEPPING=$(printf '%02x\n' $(lscpu | grep -E '^Stepping:' | awk '{print $2}'))
      MICROCODE_PATH="intel-ucode/$CPUFAM-$MODEL-$STEPPING"
      THREAD_NUM=$(nproc)
      sed -i "s#CONFIG_EXTRA_FIRMWARE=.*#CONFIG_EXTRA_FIRMWARE=\"$MICROCODE_PATH\"#g" /mnt/usr/src/.config
      sed -i "s#CONFIG_NR_CPUS=.*#CONFIG_NR_CPUS=$THREAD_NUM#g" /mnt/usr/src/.config
    fi
    ;;
  AuthenticAMD)
    basestrap /mnt amd-ucode ;;
  *)
    printf ${red}"Unsupported CPU Vendor. Possibly there is error in detection script.${normal}\n" && exit 1 ;;
esac

UUID_ROOT=$(blkid -s UUID -o value /dev/$root_drive)
UUID_BOOT=$(blkid -s UUID -o value /dev/$boot_drive)
echo "UUID=$UUID_BOOT /boot vfat defaults,noatime 0 2" > /mnt/etc/fstab
echo "UUID=$UUID_ROOT / ext4 defaults,noatime 0 1" >> /mnt/etc/fstab

_numBoot="${partition_array[0]}"
export _numBoot
export disk_drive
export root_drive
export boot_drive
export hostname
export username
export rootpass
export userpass
export choosenKernel

cp post_chroot.sh /mnt
artix-chroot /mnt ./post_chroot.sh
umount -R /mnt
echo "Linux is successfully installed!"
