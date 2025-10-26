#!/bin/bash

#set -euo pipefail

##################################################################
# Collection of helper functions


##################################################################

# Check for internet connection
if ping -c 1 ping.archlinux.org
then 
    echo "Connected to the internet, continueing..."
else 
    echo "No internet connection, pleasse connect to the internet and try again"
    exit
fi

NO_CONFIRM=0
SWAP_PART_SIZE=""
ZSWAP_ENABLED=""
ZONE=""
CITY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            echo "-y run in NO CONFIRM mode"
            echo "--swap VALUE the size of the swap partition in GiB, 0 to disable"
            echo "--zswap VALUE 0 or 1, 1 to use zswap, 0 to use zram"
            echo "--zone VALUE a valid zone entry"
            echo "--city VALUE a valid city entry"
            exit 0
            ;;
        -y)
            NO_CONFIRM=1
            ;;
        --swap)
            shift
            if [[ "$USER_IN" =~ ^-?[0-9]+$ ]]
            then
                SWAP_PART_SIZE="$1"
            fi
            ;;
        --zswap)
            shift
            if [[ "$1" == "0" || "$1" == "1" ]]
            then
                ZSWAP_ENABLED="$1"
            fi
            ;;
        --zone)
            shift
            if [[ -d "/usr/share/zoneinfo/$1" ]]
            then
                ZONE="$1"
            fi
            ;;
        --city)
            shift
            if [[ -f "/usr/share/zoneinfo/$ZONE/$1" ]]
            then
                CITY="$1"
            fi
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

PACSTRAP_PACKAGES="base base-devel linux linux-firmware nano git btrfs-progs networkmanager sudo efibootmgr bash"

# Greet
echo "Welcome to TMax07's arch install script :D"
if [[ "$NO_CONFIRM" == "$0" ]]
then
    echo "You will be asked to confirm some settings and choose a few options"
    echo "This script supports (almost) silent installs. Start the script with '--help' to list the options that need to be specified for silent installs"
    echo "A few very user specific things like Disk, Username or Password may not be automated"

    while true; do
        echo "This script will install Arch based on the developers preferences. Do you want to continue? Yn"
        read USER_IN
        if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
        then 
            echo "Aborting due to user input..."
            exit 1
        fi
        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" || "$USER_IN" == "" ]]
        then
            echo "Continueing..."
            break
        else
            echo "Invalid option, please try again"
        fi
    done
fi

# Swap partition?
if [[ "$SWAP_PART_SIZE" == "" ]]
then
    while true; do
        echo "Do you want to create a swap partiton? This will allow hibernation to be enabled: yn"
        echo "Swapfiles are not recommended on Btrfs filesystems due to complications with COW and snapshots"
        read USER_IN
        if [[ "$USER_IN" != "y" && "$USER_IN" != "Y" && "$USER_IN" != "n" && "$USER_IN" != "N" ]]
        then
            echo "Not a valid option. Try again"
            continue
        fi

        # yes no swap
        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
        then
            while true; do
                echo "Choose the swap partition size (in GiB). Should be the same as system RAM"
                read USER_IN
                # swap size
                if [[ "$USER_IN" =~ ^-?[0-9]+$ ]]
                then
                    SWAP_PART_SIZE="$USER_IN"
                    echo "Create a swap partion of size: $SWAP_PART_SIZE ? Yn"
                    read -p "" USER_IN
                    if [[ ("$USER_IN" != "y" && "$USER_IN" != "Y" && "$USER_IN" != "") ]]
                    then 
                        if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
                        then
                            echo "Aborting due to user input..."
                            exit 1
                        else
                            echo "Invalid option, please try again..."
                            continue
                        fi
                    else 
                        break
                    fi
                else
                    echo "Invalid input. Please enter a valid number."
                    continue
                fi
            done
            break
        elif [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
        then
            SWAP_PART_SIZE="0"
            break
        else
            echo "Invalid option, please try again..."
        fi
    done
fi

# ZRAM or ZSWAP
if [[ "$ZSWAP_ENABLED" == "" ]]
then
    while true; do
        echo "Please choose wether to use ZSWAP or swap to ZRAM"
        echo "If you do not want an additional swap device use ZSWAP"
        echo "ZRAM is recommended, as it increases the effictive system memory"
        echo "1) ZRAM   2) ZSWAP"
        read USER_IN
        
        if [[ "$USER_IN" == "1" ]]
        then
            echo "Will use ZRAM..."
            PACSTRAP_PACKAGES="$PACSTRAP_PACKAGES zram-generator"
            ZSWAP_ENABLED=0
            break
        fi
        if [[ "$USER_IN" == "2" ]]
        then
            echo "Will use ZSWAP"
            ZSWAP_ENABLED=1
            break
        fi
    done
fi

# Region
if [[ "$ZONE" == "" || "$CITY" == "" ]]
then
    while true; do
        echo "Choose a region: "
        ls /usr/share/zoneinfo
        read -p "" USER_IN
        if [[ -d "/usr/share/zoneinfo/$USER_IN" ]]
        then
            ZONE="$USER_IN"
            echo "Using zone: $ZONE"
            break
        else
            echo "Zone does not exist, try again..."
        fi
    done
    while true; do
        echo "Choose a city: "
        ls "/usr/share/zoneinfo/$ZONE"
        read -p "" USER_IN
        if [[ -f "/usr/share/zoneinfo/${ZONE}/$USER_IN" ]]
        then
            CITY="$USER_IN"
            echo "Using city: $CITY"
            break
        else
            echo "City does not exist, try again..."
        fi
    done
fi

# Choose a disk
echo "Please choose a disk:"
lsblk -d -n -o NAME,SIZE | awk '{print "/dev/" $1 " (" $2 ")"}'

while true; do
    read -p "Enter the disk you want to select (e.g. /dev/sda): " SELECTED_DISK
    if [[ -b "$SELECTED_DISK" ]]; then
        echo "You selected: $SELECTED_DISK, do you want to use this disk? yN" 
        read -p "" USER_IN
        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
        then
            break
        fi
    else
        echo "Invalid disk. Please try again..."
    fi
done

if [[ "$NO_CONFIRM" == "0" ]]
then
    while true; do
        echo "This will wipe all data on the disk, do you want to continue? yN"
        read USER_IN
        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
        then 
            break
        fi
        if [[ "$USER_IN" == "n" || "$USER_IN" == "N" || "$USER_IN" == "" ]]
        then
            echo "Aborting due to user input..."
            exit 1
        else
            echo "Invalid option, please try again"
        fi
    done
    while true; do
        echo "This will wipe all data on the disk! LAST CHANCE yN"
        read USER_IN
        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
        then 
            break
        fi
        if [[ "$USER_IN" == "n" || "$USER_IN" == "N" || "$USER_IN" == "" ]]
        then
            echo "Aborting due to user input..."
            exit 1
        else
            echo "Invalid option, please try again"
        fi
    done
fi

###############################################################################
# Installation start


# time
echo "--- Updating the system clock..."
timedatectl
timedatectl set-ntp true

# disk partitioning
echo "--- Continueing with disk: ${SELECTED_DISK}..."

echo "--- Wiping disk..."
# new GPT
sgdisk --zap-all "$SELECTED_DISK"
wipefs -a "$SELECTED_DISK"

echo "--- Creating partitions..."
# swap
DISK_START=2048
DISK_PART=1

echo "=== EFI"
# create a new (1GiB) EFI partition
sgdisk --new="$DISK_PART:$DISK_START:+1G" --typecode="$DISK_PART:C12A7328-F81F-11D2-BA4B-00A0C93EC93B" "$SELECTED_DISK"
DISK_START=$(sgdisk -p "$SELECTED_DISK" | awk '/^ *[0-9]+/{last=$3} END {print last}')
DISK_START=$((DISK_START+1))
DISK_PART=$((DISK_PART+1))

if [[ "$SWAP_PART_SIZE" != "0" && "$SWAP_PART_SIZE" != "" ]]
then
    echo "=== SWAP"
    # create a new swap partition
    sgdisk --new="$DISK_PART:$DISK_START:+${SWAP_PART_SIZE}G" --typecode="$DISK_PART:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" "$SELECTED_DISK"
    DISK_START=$(sgdisk -p "$SELECTED_DISK" | awk '/^ *[0-9]+/{last=$3} END {print last}') 
    DISK_START=$((DISK_START+1))
    DISK_PART=$((DISK_PART+1))
fi

echo "=== ROOT"
# create a root partiton
sgdisk --new="$DISK_PART:$DISK_START:0" --typecode="$DISK_PART:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709" "$SELECTED_DISK"

DISK_PART_NAME="$SELECTED_DISK"
if [[ "$SELECTED_DISK" == "/dev/nvme*" ]]
then
    DISK_PART_NAME="${SELECTED_DISK}p"
fi

echo "--- Formatting partitions..."
echo "=== EFI"
DISK_PART=1
# format EFI as FAT32
EFI_PART="$DISK_PART_NAME$DISK_PART"
mkfs.vfat -F32 "$EFI_PART"
DISK_PART=$((DISK_PART+1))

# format swap
SWAP_PART=""
if [[ "$SWAP_PART_SIZE" != "0" && "$SWAP_PART_SIZE" != "" ]]
then
    echo "=== SWAP"
    SWAP_PART="${DISK_PART_NAME}$DISK_PART"
    mkswap -qf "$SWAP_PART"
    DISK_PART=$((DISK_PART+1))
fi

echo "=== ROOT"
# format root partition as btrfs
ROOT_PART="${DISK_PART_NAME}$DISK_PART"
mkfs.btrfs -f "$ROOT_PART"

# create btrfs subvolumes
echo "--- Creating btrfs subvolumes..."
mount "$ROOT_PART" /mnt

echo "=== /"
btrfs subvolume create /mnt/@

echo "=== /config"
btrfs subvolume create /mnt/@config

echo "=== /home"
btrfs subvolume create /mnt/@home

echo "=== /var"
btrfs subvolume create /mnt/@var

echo "=== /var/log"
btrfs subvolume create /mnt/@var/log

echo "=== /var/cache"
btrfs subvolume create /mnt/@var/cache

echo "=== /tmp"
btrfs subvolume create /mnt/@tmp

echo "=== /.snapshots"
btrfs subvolume create /mnt/@snapshots

umount /mnt


# mount the system
echo "--- Mounting..."
echo "=== SUBVOL@"
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ "$ROOT_PART" /mnt

echo "=== SUBVOL@config"
SUBVOL="config"
mkdir -p "/mnt/$SUBVOL"
mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL"

echo "=== SUBVOL@home"
SUBVOL="home"
mkdir -p "/mnt/$SUBVOL"
mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL"

echo "=== SUBVOL@var"
SUBVOL="var"
mkdir -p "/mnt/$SUBVOL"
mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL"

echo "=== SUBVOL@var/log"
SUBVOL="var/log"
mkdir -p "/mnt/$SUBVOL"
mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL"

echo "=== SUBVOL@var/cache"
SUBVOL="var/cache"
mkdir -p "/mnt/$SUBVOL"
mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL"

echo "=== SUBVOL@tmp"
SUBVOL="tmp"
mkdir -p "/mnt/$SUBVOL"
mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL"

echo "=== SUBVOL@.snapshots"
SUBVOL="snapshots"
mkdir -p "/mnt/$SUBVOL"
mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL"

echo "=== BOOT"
mkdir -p "/mnt/boot"
mount "$EFI_PART" /mnt/boot

if [[ "$SWAP_PART" != "" ]]
then
    echo "--- Enabeling swap..."
    swapon "$SWAP_PART"
fi

################################################################################
# finish the install

# update the mirrorlist 
echo "--- Updating pacman mirrorlist..."
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# install the most basic packages
echo "--- Running pacstrap with most basic packages..."
if lscpu | grep -q Intel
then
    echo "--- Selecting intel_ucode..."
    PACSTRAP_PACKAGES="$PACSTRAP_PACKAGES intel-ucode"
else
    echo "--- Selecting amd_ucode..."
    PACSTRAP_PACKAGES="$PACSTRAP_PACKAGES amd-ucode"
fi

pacstrap -K /mnt $PACSTRAP_PACKAGES

# fstab
echo "--- Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# time
echo "--- Setting time..."
arch-chroot /mnt /bin/bash -c "ln -sf "/usr/share/zoneinfo/${ZONE}/$CITY" /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"

# set locale
echo "--- Setting language..."
echo "" >> /mnt/etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "" >> /mnt/etc/locale.gen
arch-chroot /mnt /bin/bash -c "locale-gen"
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# keyboard layout
echo "--- Setting keyboard layout to US..."
echo "KEYMAP=us" > /mnt/etc/vconsole.conf

# hostname
while true; do
    echo "Type in your hostname:"
    read USER_IN
    HOSTNAME="$USER_IN"
    echo "Set hostname to '${HOSTNAME}'? Yn"
    read USER_IN
    if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
    then
        continue
    else
        break
    fi
done
echo "--- Setting hostname..."
echo "$HOSTNAME" > /mnt/etc/hostname
echo "127.0.1.1 $HOSTNAME" > /mnt/etc/hosts

# Configure ZRAM if it is enabled
if [[ "$ZSWAP_ENABLED" == "0" ]]
then
    echo "[zram0]" > /mnt/etc/systemd/zram-generator.conf
    echo "zram-size = min(ram / 2, 4096)" >> /mnt/etc/systemd/zram-generator.conf
    echo "compression-algorithm = zstd" >> /mnt/etc/systemd/zram-generator.conf

    echo "vm.swappiness = 180" > /mnt/etc/sysctl.d/99-vm-zram-parameters.conf
    echo "vm.watermark_boost_factor = 0" >> /mnt/etc/sysctl.d/99-vm-zram-parameters.conf
    echo "vm.watermark_scale_factor = 125" >> /mnt/etc/sysctl.d/99-vm-zram-parameters.conf
    echo "vm.page-cluster = 0" >> /mnt/etc/sysctl.d/99-vm-zram-parameters.conf
fi

# mkinitcpio.conf
HIBERNATION=0
if [[ "$SWAP_PART" != "" ]]
then
    while true; do
        echo "Configured a swap partition, do you want to use it for hibernation? yn"
        read -p "" USER_IN
        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
        then
            HIBERNATION=1
            sed -i '/^HOOKS=/ s/)/ resume &/' /mnt/etc/mkinitcpio.conf
            break
        fi
        if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
        then
            break
        else
            echo "Invalid input. Try agin" 
        fi
    done
fi
echo "--- Configuring initramfs..."
sed -i 's/MODULES=()/MODULES=(btrfs)/' /mnt/etc/mkinitcpio.conf
sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt /bin/bash -c "mkinitcpio -P"

# system user
while true; do
    echo "Name the system user:"
    read -p "" USER_IN
    USER="$USER_IN"
    echo "Is $USER the correct username? Yn"
    read -p "" USER_IN
    if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
    then
        echo "Trying again..."
    else 
        break
    fi
done
PASSWORD=""
while true; do
    echo "Type in the system password"
    read -s USER_IN
    PASSWORD="$USER_IN"
    echo "Retype the system password"
    read -s USER_IN
    if [[ "$PASSWORD" == "$USER_IN" ]]
    then
        break
    else
        echo "Passwords do not match, try again"
    fi
done
echo "--- Configuring system user..."
arch-chroot /mnt /bin/bash -c "echo -e \"${PASSWORD}\n${PASSWORD}\" | passwd"
arch-chroot /mnt /bin/bash -c "useradd -mG wheel $USER"
arch-chroot /mnt /bin/bash -c "echo -e \"${PASSWORD}\n${PASSWORD}\" | passwd $USER"
echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers
arch-chroot /mnt /bin/bash -c "visudo -c"

# systemd-boot
echo "--- Installing bootloader..."
arch-chroot /mnt /bin/bash -c "bootctl install"
arch-chroot /mnt /bin/bash -c "systemctl enable systemd-boot-update.service"
echo "timeout 0" > /mnt/boot/loader/loader.conf
echo "console-mode max" >> /mnt/boot/loader/loader.conf
echo "editor no" >> /mnt/boot/loader/loader.conf

ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")

RESUME_OPTIONS=""
if [[ "$HIBERNATION" == 1 ]]
then
    SWAP_PART_UUID=$(blkid -s UUID -o value "$SWAP_PART")
    RESUME_OPTIONS="resume=UUID=$SWAP_PART_UUID"
fi

echo "title Arch Linux" > /mnt/boot/loader/entries/9-arch.conf
echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/9-arch.conf
echo "initrd /initramfs-linux.img" >> /mnt/boot/loader/entries/9-arch.conf
echo "options root=UUID=$ROOT_UUID rootflags=subvol=@ zswap.enabled=$ZSWAP_ENABLED rw rootfstype=btrfs $RESUME_OPTIONS" >> /mnt/boot/loader/entries/9-arch.conf

echo "title Arch Linux (Fallback initramfs)" > /mnt/boot/loader/entries/0-arch-fallback.conf
echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/0-arch-fallback.conf
echo "initrd /initramfs-linux-fallback.img" >> /mnt/boot/loader/entries/0-arch-fallback.conf
echo "options root=UUID=$ROOT_UUID rootflags=subvol=@ zswap.enabled=0 rw rootfstype=btrfs" >> /mnt/boot/loader/entries/0-arch-fallback.conf

arch-chroot /mnt /bin/bash -c "bootctl update"

# post install script
if [[ "$NO_CONFIRM" == "0" ]]
then
    echo "Run the default post-install script? Yn"
    read USER_IN
    if [[ "$USER_IN" != "n" && "$USER_IN" != "N" ]]
    then
        if [[ -f "/post-install.sh" ]]
        then
            mkdir /mnt/install
            cp /post-install.sh /mnt/install
        else
            pacman -Sy --noconfirm git
            git clone https://github.com/TMax07/arch-autoinstall.git /mnt/install
        fi
    fi
else
    pacman -Sy --noconfirm git
    git clone https://github.com/TMax07/arch-autoinstall.git /mnt/install
fi

arch-chroot /mnt /bin/bash -c "chmod 777 /install/post-install.sh"
echo "###--t--###--m--###--p--###" >> /mnt/home/$USER/.bash_profile
echo "/install/post-install.sh" >> /mnt/home/$USER/.bash_profile
echo "###--t--###--m--###--p--###" >> /mnt/home/$USER/.bash_profile

# done 
echo "DONE!"