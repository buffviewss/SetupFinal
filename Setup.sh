#!/bin/bash

# ===================================
# BROWSER & NEKOBOX INSTALLATION SCRIPT
# ===================================

set -euo pipefail

# === CONFIGURATION ===
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# DOWNLOAD_DIR="$HOME/Downloads/browser_setup"
# LOG_FILE="$SCRIPT_DIR/setup.log"

# Vị trí script: fallback về thư mục hiện tại khi chạy từ /dev/fd/*
SCRIPT_SRC="${BASH_SOURCE[0]:-$0}"
if [[ "$SCRIPT_SRC" == /dev/* ]]; then
  SCRIPT_DIR="$PWD"
else
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
fi

DOWNLOAD_DIR="$HOME/Downloads/browser_setup"

# Đặt log vào thư mục người dùng, luôn tồn tại
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/browser_setup"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/setup.log"


# Google Drive folder IDs
CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
FIREFOX_DRIVE_ID="1CeMNJTLgfsaFkcroOh1xpxFC-uz9HrLb"
NEKOBOX_DRIVE_ID="1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj"

# === LOGGING ===
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# === PYTHON ENVIRONMENT SETUP ===
setup_python_env() {
    log "🐍 Setting up Python environment..."

    # Install Python and pip if not available
    if ! command -v python3 &> /dev/null; then
        sudo apt update && sudo apt install -y python3 python3-pip
    fi

    # Install gdown
    if ! python3 -c "import gdown" 2>/dev/null; then
        log "📦 Installing gdown..."
        pip3 install gdown --user
    fi

    # Add pip user bin to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
}

# === BROWSER VERSION SELECTION ===
get_drive_file_list() {
    local browser_type="$1"
    local drive_id

    case $browser_type in
        chrome) drive_id="$CHROME_DRIVE_ID";;
        firefox) drive_id="$FIREFOX_DRIVE_ID";;
        *) echo "❌ Invalid browser type!"; return 1;;
    esac

    log "🔍 Getting file list from Google Drive..."

    # Create temp directory for listing files
    local temp_dir="/tmp/browser_list_$$"
    mkdir -p "$temp_dir" && cd "$temp_dir"

    # Download folder to get file list
    gdown --folder "https://drive.google.com/drive/folders/$drive_id" --no-cookies --quiet 2>/dev/null || {
        echo "❌ Failed to get file list from Drive"
        rm -rf "$temp_dir"
        return 1
    }

    # Get ALL files in the folder (any name, any extension)
    local file_list
    file_list=$(find "$temp_dir" -type f -exec basename {} \; | sort)

    # Clean up temp directory
    rm -rf "$temp_dir"

    echo "$file_list"
}

select_chrome_version() {
    local file_list
    file_list=$(get_drive_file_list "chrome")

    if [[ -z "$file_list" ]]; then
        echo "❌ Could not retrieve Chrome file list"
        echo "back"
        return 1
    fi

    echo "Choose Chrome version to download:"

    # Add download latest option
    local options=("Download Latest Chrome" "Back to main menu")

    # Add ALL files from drive (regardless of name or extension)
    while IFS= read -r file; do
        [[ -n "$file" ]] && options+=("$file")
    done <<< "$file_list"

    select version in "${options[@]}"; do
        case $version in
            "Download Latest Chrome") echo "latest"; return 0;;
            "Back to main menu") echo "back"; return 0;;
            *)
                # Accept any file name
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return 0
                else
                    echo "❌ Invalid option!"
                fi
                ;;
        esac
    done
}

select_firefox_version() {
    local file_list
    file_list=$(get_drive_file_list "firefox")

    if [[ -z "$file_list" ]]; then
        echo "❌ Could not retrieve Firefox file list"
        echo "back"
        return 1
    fi

    echo "Choose Firefox version to download:"

    # Add download latest option
    local options=("Download Latest Firefox" "Back to main menu")

    # Add ALL files from drive (regardless of name or extension)
    while IFS= read -r file; do
        [[ -n "$file" ]] && options+=("$file")
    done <<< "$file_list"

    select version in "${options[@]}"; do
        case $version in
            "Download Latest Firefox") echo "latest"; return 0;;
            "Back to main menu") echo "back"; return 0;;
            *)
                # Accept any file name
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return 0
                else
                    echo "❌ Invalid option!"
                fi
                ;;
        esac
    done
}

select_full_setup_browser() {
    echo "Choose browsers for Full Setup:"
    select choice in "Chrome only" "Firefox only" "Both Chrome & Firefox" "Back to main menu"; do
        case $choice in
            "Chrome only") echo "chrome"; return 0;;
            "Firefox only") echo "firefox"; return 0;;
            "Both Chrome & Firefox") echo "both"; return 0;;
            "Back to main menu") echo "back"; return 0;;
            *) echo "❌ Invalid option!";;
        esac
    done
}

# === DOWNLOAD FUNCTIONS ===
download_latest_browser() {
    local browser_type="$1"

    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    case $browser_type in
        chrome)
            log "📥 Downloading latest Chrome from official source..."
            wget -O chrome-latest.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
            echo "$DOWNLOAD_DIR/chrome-latest.deb"
            ;;
        firefox)
            log "📥 Downloading latest Firefox from official source..."
            # Download Firefox as .deb package for Ubuntu/Debian
            wget -O firefox-latest.deb "https://packages.mozilla.org/apt/pool/main/f/firefox/firefox_latest_amd64.deb" || {
                # Fallback to snap package
                log "📥 Installing Firefox via snap..."
                sudo snap install firefox
                echo "snap_installed"
            }
            ;;
    esac
}

download_specific_browser_file() {
    local browser_type="$1"
    local version="$2"

    if [[ $version == "latest" ]]; then
        download_latest_browser "$browser_type"
        return 0
    fi

    local drive_id
    case $browser_type in
        chrome) drive_id="$CHROME_DRIVE_ID";;
        firefox) drive_id="$FIREFOX_DRIVE_ID";;
    esac

    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    log "📥 Downloading $browser_type: $version..."

    # Download entire folder
    gdown --folder "https://drive.google.com/drive/folders/$drive_id" --no-cookies

    # Find the specific file (exact name match)
    local downloaded_file
    downloaded_file=$(find "$DOWNLOAD_DIR" -name "$version" | head -n 1)

    if [[ -z "$downloaded_file" ]]; then
        log "❌ File $version not found after download"
        return 1
    fi

    echo "$downloaded_file"
}

# === BROWSER REMOVAL ===
remove_default_browser() {
    local browser_type="$1"

    log "🗑️ Removing existing $browser_type installations..."

    case $browser_type in
        chrome)
            # Remove Chrome packages
            sudo apt remove --purge -y google-chrome-stable google-chrome-beta google-chrome-unstable 2>/dev/null || true
            sudo snap remove chromium 2>/dev/null || true
            sudo flatpak uninstall -y com.google.Chrome 2>/dev/null || true

            # Remove Chrome directories
            sudo rm -rf /opt/google/chrome* 2>/dev/null || true
            rm -rf ~/.config/google-chrome* 2>/dev/null || true
            rm -rf ~/.cache/google-chrome* 2>/dev/null || true

            # Remove desktop entries
            sudo rm -f /usr/share/applications/google-chrome*.desktop 2>/dev/null || true
            rm -f ~/.local/share/applications/google-chrome*.desktop 2>/dev/null || true
            ;;

        firefox)
            # Remove Firefox packages
            sudo apt remove --purge -y firefox firefox-esr 2>/dev/null || true
            sudo snap remove firefox 2>/dev/null || true
            sudo flatpak uninstall -y org.mozilla.firefox 2>/dev/null || true

            # Remove Firefox directories
            sudo rm -rf /opt/firefox* 2>/dev/null || true
            rm -rf ~/.mozilla/firefox* 2>/dev/null || true
            rm -rf ~/.cache/mozilla* 2>/dev/null || true

            # Remove desktop entries
            sudo rm -f /usr/share/applications/firefox*.desktop 2>/dev/null || true
            rm -f ~/.local/share/applications/firefox*.desktop 2>/dev/null || true
            ;;
    esac

    # Clean up package cache
    sudo apt autoremove -y 2>/dev/null || true
    sudo apt autoclean 2>/dev/null || true

    log "✅ $browser_type removal completed"
}

# === BROWSER INSTALLATION ===
install_chrome() {
    local chrome_file="$1"

    log "🔧 Installing Chrome from: $chrome_file"

    # Install dependencies
    sudo apt update
    sudo apt install -y wget gnupg software-properties-common apt-transport-https ca-certificates

    # Install Chrome package
    sudo dpkg -i "$chrome_file" || sudo apt install -f -y

    log "✅ Chrome installation completed"
}

install_firefox() {
    local firefox_file="$1"

    log "🔧 Installing Firefox from: $firefox_file"

    # Install dependencies
    sudo apt update
    sudo apt install -y wget software-properties-common

    # Install Firefox package
    sudo dpkg -i "$firefox_file" || sudo apt install -f -y

    log "✅ Firefox installation completed"
}

# === NEKOBOX INSTALLATION ===
install_nekobox() {
    log "🔧 Installing Nekobox..."

    setup_python_env

    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    # Download Nekobox from Google Drive
    log "📥 Downloading Nekobox from Google Drive..."
    gdown --folder "https://drive.google.com/drive/folders/$NEKOBOX_DRIVE_ID" --no-cookies

    # Find Nekobox installation file
    local nekobox_file
    nekobox_file=$(find "$DOWNLOAD_DIR" -name "*nekobox*" -o -name "*NekoBox*" | head -n 1)

    if [[ -z "$nekobox_file" ]]; then
        log "❌ Nekobox installation file not found"
        return 1
    fi

    # Install Nekobox
    if [[ "$nekobox_file" == *.deb ]]; then
        sudo dpkg -i "$nekobox_file" || sudo apt install -f -y
    elif [[ "$nekobox_file" == *.AppImage ]]; then
        chmod +x "$nekobox_file"
        sudo mv "$nekobox_file" /opt/nekobox
        sudo ln -sf /opt/nekobox /usr/local/bin/nekobox
    else
        # Generic installation
        chmod +x "$nekobox_file"
        sudo cp "$nekobox_file" /usr/local/bin/nekobox
    fi

    create_nekobox_shortcut
    log "✅ Nekobox installation completed"
}

# === SHORTCUT CREATION ===
create_browser_shortcut() {
    local browser_type="$1"

    case $browser_type in
        chrome)
            cat > ~/.local/share/applications/google-chrome.desktop << EOF
[Desktop Entry]
Version=1.0
Name=Google Chrome
Comment=Access the Internet
Exec=/usr/bin/google-chrome-stable %U
StartupNotify=true
Terminal=false
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;
EOF
            ;;
        firefox)
            cat > ~/.local/share/applications/firefox.desktop << EOF
[Desktop Entry]
Version=1.0
Name=Firefox
Comment=Browse the World Wide Web
Exec=/usr/bin/firefox %u
Icon=firefox
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;
EOF
            ;;
    esac

    chmod +x ~/.local/share/applications/${browser_type}*.desktop
    log "✅ $browser_type shortcut created"
}

create_nekobox_shortcut() {
    cat > ~/.local/share/applications/nekobox.desktop << EOF
[Desktop Entry]
Version=1.0
Name=NekoBox
Comment=Proxy client
Exec=/usr/local/bin/nekobox
Icon=nekobox
Terminal=false
Type=Application
Categories=Network;
EOF

    chmod +x ~/.local/share/applications/nekobox.desktop
    log "✅ Nekobox shortcut created"
}

# === MAIN INSTALLATION FUNCTIONS ===
install_browser_with_version_selection() {
    local browser_type="$1"
    local version_choice

    case $browser_type in
        chrome)
            version_choice=$(select_chrome_version)
            ;;
        firefox)
            version_choice=$(select_firefox_version)
            ;;
    esac

    [[ $version_choice == "back" ]] && return 0

    setup_python_env

    local selected_file
    selected_file=$(download_specific_browser_file "$browser_type" "$version_choice")

    if [[ $selected_file == "snap_installed" ]]; then
        log "✅ Firefox installed via snap"
        return 0
    fi

    if [[ -z "$selected_file" || ! -f "$selected_file" ]]; then
        log "❌ Failed to download browser installation file"
        return 1
    fi

    # Clean up unused files (keep only the selected installation file)
    find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$selected_file")" -delete

    case $browser_type in
        chrome) install_chrome "$selected_file";;
        firefox) install_firefox "$selected_file";;
    esac

    create_browser_shortcut "$browser_type"
    log "✅ $browser_type installation completed!"
}

install_full_setup() {
    local browser_choice
    browser_choice=$(select_full_setup_browser)

    [[ $browser_choice == "back" ]] && return 0

    # GỠ CÀI ĐẶT SẠCH SẼ TẤT CẢ BROWSER TRƯỚC
    log "🧹 Removing all existing browsers..."
    remove_default_browser "chrome"
    remove_default_browser "firefox"

    case $browser_choice in
        chrome)
            install_browser_with_version_selection "chrome"
            ;;
        firefox)
            install_browser_with_version_selection "firefox"
            ;;
        both)
            # Install Chrome first
            log "🔧 Installing Chrome first..."
            install_browser_with_version_selection "chrome"

            # Clean up download directory and install Firefox
            rm -rf "$DOWNLOAD_DIR" 2>/dev/null || true
            log "🔧 Installing Firefox..."
            install_browser_with_version_selection "firefox"
            ;;
    esac

    # Always install Nekobox after browser installation
    install_nekobox
}

# === MAIN MENU ===
show_main_menu() {
    clear
    echo "=================================="
    echo "  BROWSER & NEKOBOX INSTALLER"
    echo "=================================="
    echo ""
    echo "Choose an option:"

    select option in "Install Chrome only" "Install Firefox only" "Install Nekobox only" "Full Setup (Browser + Nekobox)" "Exit"; do
        case $option in
            "Install Chrome only")
                install_browser_with_version_selection "chrome"
                break
                ;;
            "Install Firefox only")
                install_browser_with_version_selection "firefox"
                break
                ;;
            "Install Nekobox only")
                install_nekobox
                break
                ;;
            "Full Setup (Browser + Nekobox)")
                install_full_setup
                break
                ;;
            "Exit")
                log "👋 Exiting installer..."
                exit 0
                ;;
            *)
                echo "❌ Invalid option! Please try again."
                ;;
        esac
    done
}

# === MAIN EXECUTION ===
main() {
    # Create log file
    touch "$LOG_FILE"

    log "🚀 Starting Browser & Nekobox Installer..."

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root!"
        exit 1
    fi

    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        echo "❌ No internet connection detected!"
        exit 1
    fi

    # Show main menu
    while true; do
        show_main_menu
        echo ""
        read -p "Press Enter to return to main menu or Ctrl+C to exit..."
    done
}

# Run main function
main "$@"
