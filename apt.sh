#!/bin/bash

set -e

DEBUG=0

# Function to handle clearing the screen
clear_screen() {
    if [[ "$DEBUG" -eq 0 ]]; then
        clear
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            DEBUG=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

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

    apt update

    echo "Updating packages for APT-based system..."
	install_if_missing() {
    	if ! command -v "$1" &> /dev/null; then
        	echo "$1 not found, installing..."
        	apt-get install -y "$1"
    	else
        	echo "$1 is already installed, continuing..."
    	fi
	}
	
	install_if_missing "sudo"
	install_if_missing "wget"

    if [[ "$OS_NAME" == "debian" ]]; then
        install_if_missing "iptables"
    fi

elif [[ "$OS_NAME" == "fedora" || "$OS_NAME" == "centos" || "$OS_NAME" == "rhel" || "$OS_NAME" == "almalinux" ]]; then
clear_screen
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

echo "Deleting any existing Spearmint folders"
rm -rf /srv/spearmint

echo "Creating new Spearmint Folder"
mkdir -p /srv/spearmint
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

rm -rf /usr/bin/spearmint

cat << 'EOF' > /usr/bin/spearmint
#!/bin/bash

# Define Peppermint installation directory
INSTALL_DIR="/srv/spearmint"

show_help() {
    echo -e "\e[92m _____                                 _       _   "
    echo -e "\e[92m/  ___|                               (_)     | |  "
    echo -e "\e[92m\ \`--. _ __   ___  __ _ _ __ _ __ ___  _ _ __ | |_ "
    echo -e "\e[92m \`--. \ '_ \ / _ \/ _\` | '__| '_ \` _ \| | '_ \| __|"
    echo -e "\e[92m/\__/ / |_) |  __/ (_| | |  | | | | | | | | | | |_ "
    echo -e "\e[92m\____/| .__/ \___|\__,_|_|  |_| |_| |_|_|_| |_|\__|"
    echo -e "\e[92m      | |                                          "
    echo -e "\e[92m      |_|                                          \e[0m"
    echo
    echo "Usage: spearmint {command}"
    echo "Please report any issues to Sydney! sydmae on Discord."
    echo "Discord Server: https://discord.gg/rhYDuSeeag"
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
        echo "Spearmint v3 Release 1 (Grazing Deer)"
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
        echo ""
        echo -e "\e[92mSpearmint Labs\e[0m, a \e[36mCloud\e[0m\e[95mExis\e[0m \e[37mLLC\e[0m Company"
        ;;
    help | "")
        show_help
        ;;
    diun)
        cd "$INSTALL_DIR"
        nano diun.yml
        ;;
    status)
        cd "$INSTALL_DIR"
        bash prettifier.sh
        ;;
    *)
        echo -e "[\e[7;31mERROR\e[0m] That command does not exist. Use spearmint help to see a list of available commands"
        ;;
esac
EOF

chmod +x /usr/bin/spearmint

echo "Deployment Information for Peppermint" > /srv/spearmint/sprmnt.txt

echo "Destroying apt folder"
rm -rf /srv/apt-spearmint

clear_screen

spearmint
