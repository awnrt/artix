LIGHTGREEN='\033[1;32m'
LIGHTRED='\033[1;91m'
WHITE='\033[1;97m'
MAGENTA='\033[1;35m'
CYAN='\033[1;96m'
NoColor='\033[0m'

printf ${LIGHTGREEN}"Do you want default linux-zen kernel or custom one?\nType 1 for default and 2 for custom:${NoColor}\n"
read _kernelflag

printf ${LIGHTGREEN}"Enter disk label (e.g. sda, nvme0n1p <- p is mandatory in nvme case):${NoColor}\n"
read disk_drive
printf ${LIGHTGREEN}"Enter comma-separated partition numbers (e.g., 5,6 for 5 boot 6 root):${NoColor}\n"
read partitions
IFS=',' read -r -a partition_array <<< "$partitions"
root_drive="$disk_drive${partition_array[1]}"
boot_drive="$disk_drive${partition_array[0]}"

printf ${LIGHTGREEN}"Enter the Hostname you want to use:${NoColor}\n"
read _hostname
printf ${LIGHTGREEN}"Enter the Username you want to use:${NoColor}\n"
read _username
printf ${LIGHTRED}"Enter the password for ROOT:${NoColor}\n"
read -s _rootpasswd
printf ${LIGHTGREEN}"Enter the password for $_username:${NoColor}\n"
read -s _userpasswd

mkfs.fat -F32 /dev/$boot_drive
mkfs.ext4 -F /dev/$root_drive

mount /dev/$root_drive /mnt
mkdir /mnt/boot
mkdir /mnt/home

if [ "$_kernelflag" -eq 1 ]; then
  mkdir /mnt/boot/efi
  mount /dev/$boot_drive /mnt/boot/efi
  rc-service ntpd start
  pacman -Sy --confirm
  basestrap /mnt base openrc seatd-openrc linux-zen linux-zen-headers 
  fstabgen -U /mnt >> /mnt/etc/fstab
  cp post_chroot.sh /mnt
elif [ "$_kernelflag" -eq 2 ]; then
  mount /dev/$boot_drive /mnt/boot
  rc-service ntpd start
  pacman -Sy --confirm
  basestrap /mnt base openrc seatd-openrc udev intel-ucode 
  UUID_ROOT=$(blkid -s UUID -o value /dev/$root_drive) 
  UUID_BOOT=$(blkid -s UUID -o value /dev/$boot_drive)
  echo "UUID=$UUID_BOOT /boot vfat defaults,noatime 0 2" > /mnt/etc/fstab
  echo "UUID=$UUID_ROOT / ext4 defaults,noatime 0 1" >> /mnt/etc/fstab
  cp post_chroot.sh /mnt
else
  printf ${LIGHTRED}"Wrong kernelflag value.${NoColor}\n"
  exit 1
fi

_numBoot="${partition_array[0]}"
export _numBoot

export disk_drive
export root_drive
export boot_drive
export _hostname
export _username
export _rootpasswd
export _userpasswd
export _kernelflag

artix-chroot /mnt ./post_chroot.sh
