#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    OS_VERSION_ID=$(echo "$VERSION_ID" | cut -d. -f1)
else
    echo "Unable to detect operating system. Exiting."
    exit 1
fi

if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
    if [[ "$OS_NAME" == "ubuntu" && ! "$OS_VERSION_ID" =~ ^(20|22|24)$ ]] || \
       [[ "$OS_NAME" == "debian" && ! "$OS_VERSION_ID" =~ ^(11|12)$ ]]; then
        echo "Warning: This script only supports Ubuntu 20.x, 22.x, 24.x, or Debian 11.x/12.x."
        exit 1
    fi

    SPEARMINT_VERSION="Spearmint v3 Release 1 (Grazing Deer)"
    SPEARMINT_INTVER="3.0.1"
    REMOTE_URL="https://raw.githubusercontent.com/SpearmintLabs/deployer/Updater-Test/index.sh"
    INSTALL_DIR="/srv/spearmint"

    remote_version=$(curl -s "$REMOTE_URL" | grep -oP 'SPEARMINT_INTVER="\K[^"]+')
    if [[ $remote_version && $remote_version != "$SPEARMINT_INTVER" ]]; then
        echo -e "[Spearmint] New Spearmint version available! $SPEARMINT_INTVER -> $remote_version"
        echo "Use 'spearmint pull' to download and install the new update."
    fi



    apt update

    echo "Updating packages for APT-based system..."
	install_if_missing() {
    	if ! command -v "$1" &> /dev/null; then
        	echo "$1 not found, installing..."
        	apt-get update && apt-get install -y "$1"
    	else
        	echo "$1 is already installed, continuing..."
    	fi
	}
	
	install_if_missing "sudo"
	install_if_missing "wget"
    install_if_missing "curl"
    install_if_missing "rsync"

    if [[ "$OS_NAME" == "debian" ]]; then
        install_if_missing "iptables"
    fi

elif [[ "$OS_NAME" == "fedora" || "$OS_NAME" == "centos" || "$OS_NAME" == "rhel" || "$OS_NAME" == "almalinux" ]]; then
clear
echo -e "[\e[7;31mFATAL\e[0m] Oops! RPM systems, like $OS_NAME are not supported at this time"
echo -e "[\e[34mINFO\e[0m] RPM Compatibility is coming in Spearmint v3 (Grazing Deer)."
exit 1
#    echo "Updating packages for RPM-based system..."
#    if command -v dnf >/dev/null 2>&1; then
#        dnf update -y
#        dnf install sudo -y
#        dnf install wget -y
#    elif command -v yum >/dev/null 2>&1; then
#        yum update -y
#        yum install sudo -y
#        yum install wget -y
#    else
#        echo "No supported package manager found (dnf/yum). Exiting."
#        exit 1
#    fi
# else
#    echo "Unsupported OS: $OS_NAME"
#    exit 1
fi

mkdir -p /srv/spearmint
mkdir -p /srv/spearmint/backup
mkdir -p /srv/spearmint/addons

cd /srv/spearmint
if [[ "$OS_NAME" == "ubuntu" ]]; then
    wget "https://i.spearmint.sh/ubuntu.sh" -O Spearmint-Installer.sh
elif [[ "$OS_NAME" == "debian" ]]; then
    wget "https://i.spearmint.sh/debian.sh" -O Spearmint-Installer.sh
elif [[ "$OS_NAME" == "fedora" || "$OS_NAME" == "centos" || "$OS_NAME" == "rhel" || "$OS_NAME" == "almalinux" ]]; then
    echo "Warning: This script is not compatible with RPM-based systems at the moment."
    echo "Compatibility is planned in v3 Release 2 (Grazing Deer)."
    exit 1
else
    echo "Unsupported OS. Exiting."
    exit 1
fi
chmod +x Spearmint-Installer.sh

cat << 'EOF' > /usr/local/bin/spearmint
#!/bin/bash

# Define Peppermint installation directory
INSTALL_DIR="/srv/spearmint"
BACKUP_DIR="/srv/spearmint/backup"
REMOTE_URL="https://raw.githubusercontent.com/SpearmintLabs/deployer/Updater-Test/index.sh"
ADDON_DIR="/srv/spearmint/addons"

backup_current_version() {
    echo "Backing up current version..."
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    rsync -a --exclude="$BACKUP_DIR" "$INSTALL_DIR/" "$BACKUP_DIR/"
    echo "Backup completed."
}




















show_addons_help() {
    echo "Addons Management Commands:"
    echo "  spearmint addons                Shows Info menu"
    echo "  spearmint addons list           Lists all available addons"
    echo "  spearmint addons install Item   Installs a specific addon (e.g., 'tmux', 'htop')"
    echo "  spearmint addons remove Item    Removes a specific addon (e.g., 'tmux', 'htop')"
}

# Function to list available addons
list_addons() {
    echo "Available Addons:"
    echo "  tmux      - Terminal multiplexer"
    echo "  htop      - Interactive process viewer"
    echo "  ncdu      - Disk usage analyzer"
    echo "  glances   - Comprehensive system monitoring"
    echo "  nmap      - Network scanner"
    echo "  fail2ban  - Intrusion prevention tool"
}

# Function to install an addon
install_addon() {
    addon="$1"
    if dpkg -s "$addon" &>/dev/null; then
        echo "$addon is already installed."
    else
        echo "Installing $addon..."
        apt-get update && apt-get install -y "$addon"
        echo "$addon installed successfully."
    fi
}

# Function to remove an addon
remove_addon() {
    addon="$1"
    if dpkg -s "$addon" &>/dev/null; then
        echo "Removing $addon..."
        apt-get remove -y "$addon"
        echo "$addon removed successfully."
    else
        echo "$addon is not installed."
    fi
}

spin() {
    local chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local colors=('\e[31m' '\e[33m' '\e[32m' '\e[36m' '\e[34m' '\e[35m')
    local delay=0.1
    local duration=10  # Duration in seconds

    echo -n "Spearmint is completing the backup task. Please wait    "
    for ((i=0; i<$duration * 10; i++)); do
        local char="${chars[i % ${#chars[@]}]}"
        local color="${colors[i % ${#colors[@]}]}"
        echo -ne "${color}${char}\e[0m\b"
        sleep $delay
    done
    echo -ne "\b"  # Clear the spinner
}













show_help() {
    echo -e '\e[92m   _____                                 _       _          ____  '
    echo -e '\e[92m  / ____|                               (_)     | |        |___ \ '
    echo -e '\e[92m | (___  _ __   ___  __ _ _ __ _ __ ___  _ _ __ | |_  __   ____) |'
    echo -e '\e[92m  \___ \| '\''_ \ / _ \/ _` | '\''__| '\''_ '\'' _ \| | '\''_ \| __| \ \ / /__ < '
    echo -e '\e[92m  ____) | |_) |  __/ (_| | |  | | | | | | | | | | |_   \ V /___) |'
    echo -e '\e[92m |_____/| .__/ \___|\__,_|_|  |_| |_| |_|_|_| |_|\__|   \_/|____/ '
    echo -e '\e[92m        | |                                                       '
    echo -e '\e[92m        |_|                                                       \e[0m'
    echo
    echo "Usage: spearmint {command}"
    echo "Please report any issues to Sydney! sydmae on Discord."
    echo "Issues: https://github.com/SpearmintLabs/Issues/issues"
    echo
    echo "Commands:"
    echo "  install   Install Peppermint ticket system"
    echo "  version   Display the Spearmint version"
    echo "  credits   Shows the credits for the script"
    echo "  start     Start the Peppermint system"
    echo "  stop      Stop the Peppermint system"
    echo "  restart   Restart the Peppermint system"
    echo "  status    Check the status of the Peppermint containers"
    echo "  upgrade   Update to the latest version of Peppermint"
    echo "  logs      Show the logs of the Peppermint and Postgres containers"
    echo "  help      Show this help menu"
    echo "  addons    See suggested packages for your server!"
    echo "  pull      Upgrades the Spearmint Installer"
    echo "  rollback  Revert to the previous installer version"
    echo
}

case "$1" in
    install)
        echo "Running Spearmint Installer..."
        if [[ -f "$INSTALL_DIR/Spearmint-Installer.sh" ]]; then
            bash "$INSTALL_DIR/Spearmint-Installer.sh"
        else
            echo "Installer script not found in $INSTALL_DIR"
        fi
        ;;
    version)
        echo "Spearmint v3 Release Canidate 3 (Snoozing Deer)"
        ;;
    start)
        echo "Starting Peppermint..."
        cd "$INSTALL_DIR"
        docker compose up -d
        ;;
    stop)
        echo "Stopping Peppermint..."
        cd "$INSTALL_DIR"
        docker compose down
        ;;
    restart)
        echo "Restarting Peppermint..."
        cd "$INSTALL_DIR"
        docker compose down && docker compose up -d
        ;;
    logs)
        echo "Opening logs..."
        cd "$INSTALL_DIR"
        docker compose logs
        ;;
    upgrade | update)
        echo "Upgrading Peppermint..."
        cd "$INSTALL_DIR"
        docker compose down
        docker compose pull
        docker compose up -d
        echo "Upgrade complete!"
        ;;
    credits)
        echo -e "\e[96mAuthor: Sydney Morrison (syd.gg)\e[0m"
        echo -e "\e[93mSpecial Mention: Jack Andrews (Creator of Peppermint)\e[0m"
        echo -e "\e[93mSpecial Mention: cutefluffypenguin (Adding additional instructions)\e[0m"
        echo ""
        echo -e "\e[92mSpearmint Labs\e[0m, a \e[36mCloud\e[0m\e[95mExis\e[0m \e[37mLLC\e[0m Company"
        ;;
    help)
        show_help
        ;;
    addons)
        case "$2" in
            help)
                show_addons_help
                ;;
            list)
                list_addons
                ;;
            install)
                if [ -z "$3" ]; then
                    echo "Please specify an addon to install, e.g., 'tmux'."
                else
                    install_addon "$3"
                fi
                ;;
            remove)
                if [ -z "$3" ]; then
                    echo "Please specify an addon to remove, e.g., 'tmux'."
                else
                    remove_addon "$3"
                fi
                ;;
            *)
                show_addons_help
                ;;
        esac
        ;;
    diun)
        cd "$INSTALL_DIR"
        nano diun.yml
        ;;
    status)
        cd "$INSTALL_DIR"
        bash prettifier.sh
        ;;
    pull) 
        backup_current_version
        clear
        (sleep 10) &
        spin
        clear
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name "backup" ! -name "addons" -exec rm -rf {} +
        wget "$REMOTE_URL" -O "/srv/spearmint/index.sh"
        mv "/srv/spearmint/index.sh" "/usr/local/bin/spearmint"
        chmod +x "/usr/local/bin/spearmint"
        echo "Upgrade complete!"
        hash -r
        echo "Spearmint has been updated" > /srv/spearmint/sprmnt.txt
        spearmint version
        ;;
    rollback)
        if [ -d "$BACKUP_DIR" ]; then
            rm -rf "$INSTALL_DIR"
            mv "$BACKUP_DIR" "$INSTALL_DIR"
            echo "Rollback completed. Reverted to previous version."
        else
            echo "No backup found to rollback."
        fi
        ;;
    *)
        echo -e "[\e[7;31mERROR\e[0m] That command does not exist. Use spearmint help to see a list of available commands"
        ;;
esac
EOF

chmod +x /usr/local/bin/spearmint

echo "Deployment Information for Peppermint" > /srv/spearmint/sprmnt.txt

clear

spearmint help