#!/bin/bash

# Color codes
ORANGE='\033[38;5;214m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
RESET='\033[0m'

# Function to check and install required packages
check_required_packages() {
    # List of required packages
    REQUIRED_PACKAGES=("ethtool" "lshw")

    # Check if each required package is installed
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            missing_packages+=("$package")
        fi
    done

    # If there are any missing packages, prompt the user to install them
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo -e "${RED}The following required packages are missing:${RESET} ${missing_packages[*]}"
        echo -e "${CYAN}Would you like to install them now? (y/n): ${RESET}"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            install_required_packages
        else
            echo -e "${RED}Please install the missing packages manually and re-run the script.${RESET}"
            exit 1
        fi
    fi
}

# Function to install missing required packages
install_required_packages() {
    # Check if sudo is available, if not check for root
    if ! command -v sudo &> /dev/null; then
        if [ "$(id -u)" -ne 0 ]; then
            echo -e "${RED}Error: 'sudo' is not installed, and you are not running the script as root.${RESET}"
            echo "Please install 'sudo' or run the script as root."
            exit 1
        else
            echo -e "${RED}Warning: 'sudo' is not installed, using root privileges directly.${RESET}"
            install_packages_as_root
        fi
    else
        sudo_installed=true
        sudo_update_and_install
    fi
}

# Function to install packages with root privileges
install_packages_as_root() {
    echo "Installing required packages as root..."
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y ethtool lshw
    elif command -v yum &> /dev/null; then
        yum install -y ethtool lshw
    elif command -v dnf &> /dev/null; then
        dnf install -y ethtool lshw
    else
        echo -e "${RED}Error: Unable to detect package manager. Please install ethtool and lshw manually.${RESET}"
        exit 1
    fi
}

# Function to install packages using sudo (if sudo is available)
sudo_update_and_install() {
    echo "Installing required packages using sudo..."
    sudo apt-get update
    sudo apt-get install -y ethtool lshw
}

# Call the check_required_packages function at the beginning of the script
check_required_packages


# Get interface -> card name map
declare -A IFACE_TO_CARD
current_iface=""
current_product=""

while IFS= read -r line; do
    if [[ $line =~ logical\ name:\ (.+) ]]; then
        current_iface="${BASH_REMATCH[1]}"
        if [[ -n $current_product ]]; then
            IFACE_TO_CARD["$current_iface"]="$current_product"
            current_product=""
        fi
    elif [[ $line =~ product:\ (.+) ]]; then
        current_product="${BASH_REMATCH[1]}"
    fi
done < <(lshw -class network -sanitize 2>/dev/null)

# Function for Physical Interface Info
get_physical_iface_info() {
    local iface=$1
    card_name="${IFACE_TO_CARD[$iface]:-Unknown}"
    mac=$(cat /sys/class/net/$iface/address)
    mtu=$(cat /sys/class/net/$iface/mtu)
    echo -e "=== ${CYAN}$iface${RESET} — $card_name"
    echo "  MAC: $mac"
    echo "  MTU: $mtu"

    # Show IP address (IPv4 only)
    ip -o -4 addr show "$iface" | awk '{print "  IP: " $4}'

    # Show member interfaces for bridges and bonds
    if [[ -d /sys/class/net/$iface/brif ]]; then
        members=$(ls /sys/class/net/$iface/brif 2>/dev/null | paste -sd, -)
        echo "  Members (bridge): $members"
    elif [[ -f /sys/class/net/$iface/bonding/slaves ]]; then
        members=$(cat /sys/class/net/$iface/bonding/slaves | xargs)
        echo "  Members (bond): $members"
    fi

    # Get ethtool info
    ethtool_output=$(ethtool "$iface")

    # Available speeds
    speeds=$(echo "$ethtool_output" | awk '/Supported link modes:/{flag=1; next} /Advertised link modes:/{flag=0} flag' |
             grep -oE '[0-9]+base' | grep -oE '[0-9]+' | sort -n -u | paste -sd, -)
    echo "  Available Speeds: $speeds"

    # Current speed and link status
    link=$(echo "$ethtool_output" | grep "Link detected:" | awk '{print $3}')
    speed=$(echo "$ethtool_output" | grep "Speed:" | awk '{print $2}')

    # If speed is not available, fallback to "Unknown"
    if [[ -z "$speed" ]]; then
        speed="Unknown"
    fi

    # Color-coded speed
    color=$RESET
    case "$speed" in
        100Mb/s) color=$ORANGE ;;
        1000Mb/s) color=$GREEN ;;
        2500Mb/s|5000Mb/s|10000Mb/s|25000Mb/s|40000Mb/s|100000Mb/s) color=$BLUE ;;
    esac

    # Check link status and set color/icon
    if [[ "$link" == "yes" ]]; then
        link_color=$GREEN
        link_icon="🟢"  # Green dot for YES
        link_status="YES"
    else
        link_color=$RED
        link_icon="🔴"  # Red dot for NO
        link_status="NO"
    fi

    # Output the link speed with color
    echo -e "  Speed: ${color}$speed${RESET}"

    # Output the status with the dot and color for Link detection
    echo -e "  Link detected: ${link_color}$link_status${RESET} $link_icon"

    # Additional Info: MTU and MAC
    echo "  MTU: $mtu"
    echo "  MAC: $mac"

    echo ""
}

# Function for Virtual Interface Info (Bridge / Bond)
get_virtual_iface_info() {
    local iface=$1
    card_name="${IFACE_TO_CARD[$iface]:-Unknown}"
    mac=$(cat /sys/class/net/$iface/address)
    mtu=$(cat /sys/class/net/$iface/mtu)
    echo -e "=== ${CYAN}$iface${RESET} — $card_name"
    echo "  MAC: $mac"
    echo "  MTU: $mtu"

    # Show IP address (IPv4 only)
    ip -o -4 addr show "$iface" | awk '{print "  IP: " $4}'

    members=""
    is_bridge=false
    is_bond=false

    if [[ -d /sys/class/net/$iface/brif ]]; then
        is_bridge=true
        members=$(ls /sys/class/net/$iface/brif 2>/dev/null | paste -sd' ' -)
        echo "  Members (bridge): ${members// /, }"
    elif [[ -f /sys/class/net/$iface/bonding/slaves ]]; then
        is_bond=true
        members=$(cat /sys/class/net/$iface/bonding/slaves | xargs)
        echo "  Members (bond): ${members// /, }"
        bond_mode=$(cat /sys/class/net/$iface/bonding/mode 2>/dev/null)
        echo "  Bond Mode: $bond_mode"
    fi

    # Determine bond speed from active slave or fallback to first member
    if [[ "$is_bond" == true ]]; then
        active_slave=$(grep "Currently Active Slave:" /proc/net/bonding/$iface 2>/dev/null | awk -F': ' '{print $2}')

        if [[ -z "$active_slave" && -n "$members" ]]; then
            active_slave=$(echo "$members" | awk '{print $1}')
            fallback=true
        else
            fallback=false
        fi

        if [[ -n "$active_slave" ]]; then
            member_speed=$(ethtool "$active_slave" 2>/dev/null | grep "Speed:" | awk '{print $2}')
            label="via ${fallback:+first member }$active_slave"

            # Determine color
            speed_color=$RESET
            case "$member_speed" in
                100Mb/s) speed_color=$ORANGE ;;
                1000Mb/s) speed_color=$GREEN ;;
                2500Mb/s|5000Mb/s|10000Mb/s|25000Mb/s|40000Mb/s|100000Mb/s) speed_color=$BLUE ;;
            esac

            echo -e "  Speed ($label): ${speed_color}${member_speed:-Unknown}${RESET}"
        fi
    fi


    # Aggregate available speeds from member interfaces
    if [[ -n "$members" ]]; then
        all_speeds=()
        for member in $members; do
            if ethtool "$member" &>/dev/null; then
                speeds=$(ethtool "$member" | awk '/Supported link modes:/{flag=1; next} /Advertised link modes:/{flag=0} flag' |
                         grep -oE '[0-9]+base' | grep -oE '[0-9]+' | sort -n -u)
                all_speeds+=($speeds)
            fi
        done
        unique_speeds=$(printf "%s\n" "${all_speeds[@]}" | sort -n -u | paste -sd, -)
        echo "  Available Speeds (from members): $unique_speeds"
    else
        echo "  Available Speeds: Unknown (no members)"
    fi

    if [[ "$is_bridge" == true && -n "$members" ]]; then
        main_member=$(echo "$members" | awk '{print $1}')

        # Skip if main member is a bond (avoid duplicate speed print)
        if [[ ! -f "/proc/net/bonding/$main_member" ]]; then
            member_speed=$(ethtool "$main_member" 2>/dev/null | grep "Speed:" | awk '{print $2}')
            speed_color=$RESET
            case "$member_speed" in
                100Mb/s) speed_color=$ORANGE ;;
                1000Mb/s) speed_color=$GREEN ;;
                2500Mb/s|5000Mb/s|10000Mb/s|25000Mb/s|40000Mb/s|100000Mb/s) speed_color=$BLUE ;;
            esac
            echo -e "  Speed (via $main_member): ${speed_color}${member_speed:-Unknown}${RESET}"
        fi
    fi


    # Link detection and status
    link=$(ethtool "$iface" 2>/dev/null | grep "Link detected:" | awk '{print $3}')
    if [[ "$link" == "yes" ]]; then
        link_color=$GREEN
        link_icon="🟢"
        link_status="YES"
    else
        link_color=$RED
        link_icon="🔴"
        link_status="NO"
    fi

    echo -e "  Link detected: ${link_color}$link_status${RESET} $link_icon"
    echo ""
}


# Loop through interfaces
for iface in $(ls /sys/class/net); do
    if ethtool "$iface" &>/dev/null; then
        # Determine if interface is physical or virtual (bridge/bond)
        if [[ -d /sys/class/net/$iface/brif ]] || [[ -f /sys/class/net/$iface/bonding/slaves ]]; then
            # Virtual interface (bridge or bond)
            get_virtual_iface_info "$iface"
        else
            # Physical interface
            get_physical_iface_info "$iface"
        fi
    fi
done
