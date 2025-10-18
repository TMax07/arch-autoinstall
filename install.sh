#!/bin/bash

umount -R /mnt > /dev/null
umount /btrfs > /dev/null
rm -rf /btrfs > /dev/null

##################################################################
# Collection of helper functions


##################################################################

# Check for internet connection
if ping -c 1 ping.archlinux.org > /dev/null
then 
    echo "Connected to the internet, continueing..."
else 
    echo "No internet connection, pleasse connect to the internet and try again"
    exit
fi

echo "Updating the system clock..."
timedatectl > /dev/null
timedatectl set-ntp true > /dev/null

# Choose a disk
echo "--- Choose a disk:"
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

echo "Continueing with disk: ${SELECTED_DISK}..."
# Disk isnatll type
while true; do
    echo "--- Please choose an install type: "
    echo "1) Full disk   2) Root only  3) Skip  4) Abort"
    read -p "" USER_IN
    # full disk 
    if [[ "$USER_IN" == "1" ]] 
    then
        echo "This will create a new btrfs install. To create another install type please edit the script..."
        echo "Continue? Yn"
        read -p "" USER_IN
        if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
        then
            continue
        fi

        # Swap partition?
        echo "--- Create a swap partition? This will allow hibernation to be enabled: yn"
        read -p "" USER_IN
        if [[ "$USER_IN" != "y" && "$USER_IN" != "Y" && "$USER_IN" != "n" && "$USER_IN" != "N" ]]
        then
            echo "Not a valid option. Try again"
            continue
        fi

        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
        then
            echo "--- Choose swap partition size (in GiB). Should be the same as system RAM"
            read -p "" USER_IN
            if [[ "$USER_IN" =~ ^-?[0-9]+$ ]]
            then
                SWAP_SIZE="$USER_IN"
                echo "Create a swap partion of size: $SWAP_SIZE ? Yn"
                read -p "" USER_IN
                if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
                then
                    continue
                fi
            else
                echo "Invalid input. Please enter a valid number."
                continue
            fi
        else
            SWAP_SIZE="0"
        fi

        echo "WARNING: THIS WILL WIPE THE ENTIRE SELECTED DISK"
        echo "ARE YOU SURE YOU WANT TO CONTINUE? --- yN"
        read -p "" USER_IN
        if [[ "$USER_IN" == "y" || "$USER_IN" == "Y" ]]
        then
            echo "Wiping disk..."
            # new GPT
            sgdisk --zap-all "$SELECTED_DISK" > /dev/null
            wipefs -a $SELECTED_DISK > /dev/null

            echo "Creating partitions..."
            # swap
            DISK_START=2048
            DISK_PART=1

            echo "=== EFI"
            # create a new (1GiB) EFI partition
            sgdisk --new="$DISK_PART:$DISK_START:+1G" --typecode="$DISK_PART:C12A7328-F81F-11D2-BA4B-00A0C93EC93B" "$SELECTED_DISK" > /dev/null
            DISK_START=$(sgdisk -p "$SELECTED_DISK" | awk '/^ *[0-9]+/{last=$3} END {print last}')
            DISK_START=$((DISK_START+1))
            DISK_PART=$((DISK_PART+1))

            if [[ "$SWAP_SIZE" != "0" ]]
            then
                echo "=== SWAP"
                # create a new swap partition
                sgdisk --new="$DISK_PART:$DISK_START:+${SWAP_SIZE}G" --typecode="$DISK_PART:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" "$SELECTED_DISK" > /dev/null
                DISK_START=$(sgdisk -p "$SELECTED_DISK" | awk '/^ *[0-9]+/{last=$3} END {print last}') 
                DISK_START=$((DISK_START+1))
                DISK_PART=$((DISK_PART+1))
            fi

            echo "=== ROOT"
            # create a root partiton
            sgdisk --new="$DISK_PART:$DISK_START:0" --typecode="$DISK_PART:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709" "$SELECTED_DISK" > /dev/null

            DISK_PART_NAME="$SELECTED_DISK"
            if [[ "$SELECTED_DISK" == "nvme*" ]]
            then
                DISK_PART_NAME="${SELECTED_DISK}p"
            fi

            echo "Formatting partitions..."
            echo "=== EFI"
            DISK_PART=1
            # format EFI as FAT32
            EFI_PART="$DISK_PART_NAME$DISK_PART"
            mkfs.vfat -F32 "$EFI_PART" > /dev/null
            DISK_PART=$((DISK_PART+1))

            # format swap
            SWAP_PART=""
            if [[ "$SWAP_SIZE" != "0" ]]
            then
                echo "=== SWAP"
                SWAP_PART="${DISK_PART_NAME}$DISK_PART"
                mkswap -qf "$SWAP_PART" > /dev/null
                DISK_PART=$((DISK_PART+1))
            fi

            echo "=== ROOT"
            # format root partition as btrfs
            ROOT_PART="${DISK_PART_NAME}$DISK_PART"
            mkfs.btrfs -f "$ROOT_PART" > /dev/null
            
            # create btrfs subvolumes
            echo "Creating btrfs subvolumes..."
            mount "$ROOT_PART" /mnt > /dev/null

            echo "=== /"
            btrfs subvolume create /mnt/@ > /dev/null

            echo "=== /config"
            btrfs subvolume create /mnt/@config > /dev/null

            echo "=== /home"
            btrfs subvolume create /mnt/@home > /dev/null

            echo "=== /var"
            btrfs subvolume create /mnt/@var > /dev/null

            echo "=== /var/log"
            btrfs subvolume create /mnt/@var/log > /dev/null

            echo "=== /var/cache"
            btrfs subvolume create /mnt/@var/cache > /dev/null

            echo "=== /tmp"
            btrfs subvolume create /mnt/@tmp > /dev/null

            echo "=== /.snapshots"
            btrfs subvolume create /mnt/@.snapshots > /dev/null

            umount /mnt > /dev/null


            # mount the system
            echo "Mounting..."
            echo "=== SUBVOL@"
            mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ "$ROOT_PART" /mnt > /dev/null

            echo "=== SUBVOL@config"
            SUBVOL="config"
            mkdir -p "/mnt/$SUBVOL" > /dev/null
            mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL" > /dev/null

            echo "=== SUBVOL@home"
            SUBVOL="home"
            mkdir -p "/mnt/$SUBVOL" > /dev/null
            mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL" > /dev/null

            echo "=== SUBVOL@var"
            SUBVOL="var"
            mkdir -p "/mnt/$SUBVOL" > /dev/null
            mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL" > /dev/null

            echo "=== SUBVOL@var/log"
            SUBVOL="var/log"
            mkdir -p "/mnt/$SUBVOL" > /dev/null
            mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL" > /dev/null

            echo "=== SUBVOL@var/cache"
            SUBVOL="var/cache"
            mkdir -p "/mnt/$SUBVOL" > /dev/null
            mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL" > /dev/null

            echo "=== SUBVOL@tmp"
            SUBVOL="tmp"
            mkdir -p "/mnt/$SUBVOL" > /dev/null
            mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL" > /dev/null

            echo "=== SUBVOL@.snapshots"
            SUBVOL=".snapshots"
            mkdir -p "/mnt/$SUBVOL" > /dev/null
            mount -o "rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@$SUBVOL" "$ROOT_PART" "/mnt/$SUBVOL" > /dev/null

            echo "=== BOOT"
            mkdir -p "/mnt/boot" > /dev/null
            mount "$EFI_PART" /mnt/boot > /dev/null
            
            if [[ "$SWAP_PART" != "" ]]
            then
                echo "Enabeling swap..."
                swapon "$SWAP_PART" > /dev/null
            fi
            break
        fi
    fi
done

# the system is partinoned and mounted properly now
# start the general installation

# update the mirrorlist 
echo "Updating pacman mirrorlist..."
#reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# install the most basic packages
echo "Running pacstrap with most basic packages..."
PACSTRAP_PACKAGES="base base-devel linux linux-firmware nano git btrfs-progs networkmanager sudo"
if lscpu | grep -q Intel
then
    echo "Selecting intel_ucode..."
    PACSTRAP_PACKAGES="$PACSTRAP_PACKAGES intel-ucode"
else
    echo "Selecting amd_ucode..."
    PACSTRAP_PACKAGES="$PACSTRAP_PACKAGES amd-ucode"
fi

pacstrap -K /mnt $PACSTRAP_PACKAGES

# fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab > /dev/null

# time
while true; do
    echo "Choose a region: "
    ls /usr/share/zoneinfo
    read -p "" USER_IN
    if [[ -d "/mnt/usr/share/zoneinfo/$USER_IN" ]]
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
    if [[ -f "/mnt/usr/share/zoneinfo/${ZONE}/$USER_IN" ]]
    then
        CITY="$USER_IN"
        echo "Using city: $CITY"
        break
    else
        echo "City does not exist, try again..."
    fi
done

echo "Setting time..."
arch-chroot /mnt /bin/bash -c "ln -sf "/usr/share/zoneinfo${ZONE}/$CITY" /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"

# set locale
echo "Setting language..."
echo "" >> /mnt/etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "" >> /mnt/etc/locale.gen
arch-chroot /mnt /bin/bash -c "locale-gen" > /dev/null
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# keyboard layout
echo "Setting keyboard layout to US..."
echo "KEYMAP=us" > /mnt/etc/vconsole.conf

# hostname
while true; do
    echo "Type in your hostname: "
    read -p "" USER_IN
    HOSTNAME="$USER_IN"
    echo "Set hostname to '${HOSTNAME}'? Yn"
    read -p "" USER_IN
    if [[ "$USER_IN" == "n" || "$USER_IN" == "N" ]]
    then
        continue
    else
        break
    fi
done
echo "Setting hostname..."
echo "$HOSTNAME" > /mnt/etc/hostname
echo "127.0.1.1 $HOSTNAME" > /mnt/etc/hosts

ZSWAP_ENABLED=0
echo "Enable zswap? Yn"
read -p "" USER_IN
if [[ "$USER_IN" != "n" && "$USER_IN" != "N" ]]
then
    echo "Enabeling zswap"
    ZSWAP_ENABLED=1
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
            sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems resume fsck)/' /mnt/etc/mkinitcpio.conf > /dev/null
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
echo "Configuring initramfs..."
sed -i 's/MODULES=()/MODULES=(btrfs)/' /mnt/etc/mkinitcpio.conf > /dev/null
sed -i 's/BINARIES=()/BINARIES=(\/usr\/bin\/btrfs)/' /mnt/etc/mkinitcpio.conf > /dev/null
arch-chroot /mnt /bin/bash -c "mkinitcpio -P" > /dev/null

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
while true; do
    echo "Type in the system password"
    read -s -p "" USER_IN
    PASSWORD="$USER_IN"
    echo "Retype the system password"
    read -s -p "" USER_IN
    if [[ "$PASSWORD" == "$USER_IN" ]]
    then
        break
    else
        echo "Passwords do not match, try again"
    fi
done
echo "Configuring system user..."
arch-chroot /mnt /bin/bash -c "echo -e \"${PASSWORD}\n${PASSWORD}\" | passwd" > /dev/null
arch-chroot /mnt /bin/bash -c "useradd -mG wheel $USER" > /dev/null
arch-chroot /mnt /bin/bash -c "echo -e \"${PASSWORD}\n${PASSWORD}\" | passwd $USER" > /dev/null
echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers
arch-chroot /mnt /bin/bash -c "visudo -c"

# systemd-boot
echo "Installing bootloader..."
arch-chroot /mnt /bin/bash -c "bootctl install"
arch-chroot /mnt /bin/bash -c "systemctl enable systemd-boot-update.service"
echo "timeout 0" > /mnt/boot/loader/loader.conf
echo "console-mode max" >> /mnt/boot/loader/loader.conf
echo "editor no" >> /mnt/boot/loader/loader.conf

mkdir /btrfs
mount -o "subvolid=5" $ROOT_PART /btrfs
BTRFS_ROOT_UUID=$(btrfs subvolume show /btrfs/@ | grep UUID | awk '{print $2}' | grep -)
umount /btrfs

RESUME_OPTIONS=""
if [[ "$HIBERNATION" == 1 ]]
then
    SWAP_PART_UUID=$(lsblk -dno UUID $SWAP_PART)
    RESUME_OPTIONS="resume=UUID=$SWAP_PART_UUID"
fi

echo "title Arch Linux" > /mnt/boot/loader/entries/9-arch.conf
echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/9-arch.conf
echo "initrd /initramfs-linux.img" >> /mnt/boot/loader/entries/9-arch.conf
echo "options root=UUID=$BTRFS_ROOT_UUID rootflags=subvol=@ zswap.enabled=$ZSWAP_ENABLED rw rootfstype=btrfs $RESUME_OPTIONS" >> /mnt/boot/loader/entries/9-arch.conf

echo "title Arch Linux (Fallback initramfs)" > /mnt/boot/loader/entries/0-arch-fallback.conf
echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/0-arch-fallback.conf
echo "initrd /initramfs-linux-fallback.img" >> /mnt/boot/loader/entries/0-arch-fallback.conf
echo "options root=UUID=$BTRFS_ROOT_UUID rootflags=subvol=@ zswap.enabled=$ZSWAP_ENABLED rw rootfstype=btrfs" >> /mnt/boot/loader/entries/0-arch-fallback.conf

arch-chroot /mnt /bin/bash -c "bootctl update" > /dev/null

# post install script 
echo "Run the default post-install script? Yn"
read -p "" USER_IN
if [[ "$USER_IN" != "n" && "$USER_IN" != "N" ]]
then
    if [[ -f "/post-install.sh" ]]
    then
        mkdir /mnt/install
        cp /post-install.sh /mnt/install
    else
        pacman -Sy --noconfirm git > /dev/null
        git clone https://github.com/TMax07/arch-autoinstall.git /mnt/install > /dev/null
    fi

    arch-chroot /mnt /bin/bash -c "chmod 777 /mnt/install/post-install.sh" > /dev/null
    arch-chroot /mnt /bin/bash -c "chmod +x /mnt/install/post-install.sh" > /dev/null
    echo "/install/post-install.sh" >> /mnt/home/$USER/.bash_profile
fi

# done 
echo "DONE!"