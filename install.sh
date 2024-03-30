read -p "Enter disk label (e.g., sda): " disk_drive
read -p "Enter comma-separated partition numbers (e.g., 5,6,7 for 5 boot 6 swap 7 root): " partitions
IFS=',' read -r -a partition_array <<< "$partitions"

root_drive="$disk_drive${partition_array[2]}"
swap_drive="$disk_drive${partition_array[1]}"
boot_drive="$disk_drive${partition_array[0]}"

read -p "Hostname: " _hostname

read -p "Username: " _username

read -p "root password: " _rootpasswd

read -p "user password: " _userpasswd

mkfs.ext4 /dev/$root_drive
mkswap /dev/$swap_drive
swapon /dev/$swap_drive
mkfs.fat -F 32 /dev/$boot_drive

mount /dev/$root_drive /mnt
mkdir /mnt/boot
mkdir /mnt/home
mkdir /mnt/boot/efi
mount /dev/$boot_drive /mnt/boot/efi

rc-service ntpd start

pacman -Sy --confirm
pacman -S pacman-contrib --noconfirm

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

basestrap /mnt base base-devel openrc elogind-openrc
basestrap /mnt linux linux-firmware
fstabgen -U /mnt >> /mnt/etc/fstab

cp post_chroot.sh /mnt

export root_drive
export swap_drive
export boot_drive
export _hostname
export _username
export _rootpasswd
export _userpasswd

artix-chroot /mnt ./post_chroot.sh
