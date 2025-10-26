#!/bin/bash

INPUT_FILE="/config/pkgs"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

INPUT_FILE_TXT=$(cat $INPUT_FILE)

# Read exclude list
echo "Available groups: "
current_group=0
for line in $INPUT_FILE_TXT
do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Detect new group
    if [[ "$line" == ===* ]]; then
        ((current_group++))
        echo "$current_group) ${line#*===}"
    fi
done
read -rp "Enter group numbers to exclude (e.g., 1 4 9): " -a EXCLUDED_GROUPS

is_excluded() {
    local group_num=$1
    for ex in "${EXCLUDED_GROUPS[@]}"; do
        if [[ "$ex" == "$group_num" ]]; then
            return 0
        fi
    done
    return 1
}

read_pkg_line() {
    local line="$1"
    PKG_NAME="${line%%:::*}"
    rest="${line#*:::}"
    DL_CL="${rest%%:::*}"
    SCRIPT_PATH="${rest#*:::}"
    [[ "$SCRIPT_PATH" == "$rest" ]] && SCRIPT_PATH="" 
}

current_group=0
include_group=true
cur_pacman_pkgs=""
cur_yay_pkgs=""
cur_flatpak_pks=""
cur_flathub_pks=""

function install_pkgs() {
    if [[ "$cur_flathub_pks" != "" ]]
    then
        flatpak install flathub -y "$cur_flathub_pks"
    fi
    if [[ "$cur_flatpak_pks" != "" ]]
    then
        flatpak install -y "$cur_flatpak_pks"
    fi
    if [[ "$cur_yay_pkgs" != "" ]]
    then
        yay -S --noconfirm "$cur_yay_pkgs"
    fi
    if [[ "$cur_pacman_pkgs" != "" ]]
    then
        pacman -S --noconfirm "$cur_pacman_pkgs"
    fi

    cur_pacman_pkgs=""
    cur_yay_pkgs=""
    cur_flatpak_pks=""
    cur_flathub_pks=""
}

for line in $INPUT_FILE_TXT
do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Detect new group
    if [[ "$line" == ===* ]]; then
        ((current_group++))
        if is_excluded "$current_group"; then
            include_group=false
            echo "Skipping group $current_group"
        else
            include_group=true
            echo "Processing group $current_group"
        fi
        continue
    fi

    # Skip packages from excluded groups
    if ! $include_group; then
        continue
    fi

    # Parse line: PKG_NAME:::DL_CL:::SCRIPT_PATH (SCRIPT_PATH optional)
    read_pkg_line "$line"

    if [[ -z "$PKG_NAME" || -z "$DL_CL" ]]; then
        echo "Skipping malformed line: $line"
        continue
    fi

    echo "Installing $PKG_NAME via $DL_CL..."

    # Batch pkgs for install
    case "$DL_CL" in
        pacman)
            cur_pacman_pkgs="$cur_pacman_pkgs $PKG_NAME"
            #sudo pacman -S --noconfirm "$PKG_NAME"
            ;;
        yay)
            cur_yay_pkgs="$cur_yay_pkgs $PKG_NAME"
            #yay -S --noconfirm "$PKG_NAME"
            ;;
        flatpak)
            cur_flatpak_pks="$cur_flatpak_pks $PKG_NAME"
            #flatpak install -y "$PKG_NAME"
            ;;
        flathub)
            cur_flathub_pks="$cur_flathub_pks $PKG_NAME"
            #flatpak install flathub -y "$PKG_NAME"
            ;;
        *)
            echo "Unknown installer type '$DL_CL' for package '$PKG_NAME'"
            continue
            ;;
    esac

    # Run optional post-install script
    # Break batch on install script
    if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
        install_pkgs

        sudo chmod +x "$SCRIPT_PATH"
        sudo bash "$SCRIPT_PATH"
    fi
done

# straggling packages
install_pkgs
