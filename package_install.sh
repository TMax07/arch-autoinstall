#!/usr/bin/env bash
#set -euo pipefail

INPUT_FILE="/config/pkgs"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Read exclude list
echo "Available groups: "
current_group=0
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Detect new group
    if [[ "$line" == ===* ]]; then
        ((current_group++))
        echo "$current_group) ${line#*===}"
    fi
done < "$INPUT_FILE"
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
    PATH="${rest#*:::}"
    [[ "$PATH" == "$rest" ]] && PATH="" 
}

current_group=0
include_group=true

while IFS= read -r line || [[ -n "$line" ]]; do
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

    # Parse line: PKG_NAME:::DL_CL:::PATH (PATH optional)
    read_pkg_line "$line"

    if [[ -z "$PKG_NAME" || -z "$DL_CL" ]]; then
        echo "Skipping malformed line: $line"
        continue
    fi

    echo "Installing $PKG_NAME via $DL_CL..."

    case "$DL_CL" in
        pacman)
            sudo pacman -S --noconfirm "$PKG_NAME"
            ;;
        yay)
            yay -S --noconfirm "$PKG_NAME"
            ;;
        flatpak)
            flatpak install -y "$PKG_NAME"
            ;;
        flathub)
            flatpak install flathub -y "$PKG_NAME"
        *)
            echo "Unknown installer type '$DL_CL' for package '$PKG_NAME'"
            continue
            ;;
    esac

    # Run optional post-install script
    if [[ -n "$PATH" && -f "$PATH" ]]; then
        sudo chmod +x "$PATH"
        sudo bash "$PATH"
    fi

done < "$INPUT_FILE"

