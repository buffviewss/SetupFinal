#!/bin/bash

# ===================================
# BROWSER & NEKOBOX INSTALLATION SCRIPT
# ===================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="$HOME/Downloads/browser_setup"
LOG_FILE="$SCRIPT_DIR/setup.log"
MACHINE_ID_FILE="$SCRIPT_DIR/machine_id.txt"

# Google Drive folder IDs
CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
FIREFOX_DRIVE_ID="1CeMNJTLgfsaFkcroOh1xpxFC-uz9HrLb"
NEKOBOX_DRIVE_ID="1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj"

# Ubuntu/Lubuntu 24.04 compatibility
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "24.04")
DESKTOP_ENV=""

# Font and Audio arrays for randomization
FONTS_LIST=(
    "fonts-noto" "fonts-liberation" "fonts-dejavu" "fonts-ubuntu" 
    "fonts-roboto" "fonts-open-sans" "fonts-lato" "fonts-source-code-pro"
    "fonts-firacode" "fonts-cascadia-code" "fonts-jetbrains-mono"
    "fonts-hack" "fonts-inconsolata" "fonts-droid-fallback"
)

AUDIO_THEMES=(
    "ubuntu" "smooth" "stereo" "freedesktop" "speech-dispatcher"
)

# === LOGGING ===
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# === SYSTEM DETECTION ===
detect_desktop_environment() {
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
    elif pgrep -x "lxqt-session" > /dev/null; then
        DESKTOP_ENV="LXQt"
    elif pgrep -x "lxsession" > /dev/null; then
        DESKTOP_ENV="LXDE"
    elif pgrep -x "gnome-session" > /dev/null; then
        DESKTOP_ENV="GNOME"
    elif pgrep -x "xfce4-session" > /dev/null; then
        DESKTOP_ENV="XFCE"
    else
        DESKTOP_ENV="Unknown"
    fi
    
    log "🖥️ Detected desktop environment: $DESKTOP_ENV"
    log "🐧 Ubuntu version: $UBUNTU_VERSION"
}

# === MACHINE ID GENERATION ===
generate_machine_id() {
    if [[ ! -f "$MACHINE_ID_FILE" ]]; then
        # Generate unique machine ID based on hardware info
        local machine_id
        machine_id=$(cat /proc/cpuinfo /proc/meminfo 2>/dev/null | md5sum | cut -d' ' -f1 | head -c 8)
        echo "$machine_id" > "$MACHINE_ID_FILE"
        log "🆔 Generated new machine ID: $machine_id"
    fi
    
    cat "$MACHINE_ID_FILE"
}

# === RANDOM FONT SELECTION ===
install_random_fonts() {
    log "🎨 Installing random fonts for this machine..."
    
    local machine_id
    machine_id=$(generate_machine_id)
    
    # Use machine ID as seed for consistent randomization
    local seed=$((0x${machine_id:0:8}))
    RANDOM=$seed
    
    # Select 3-5 random fonts
    local num_fonts=$((RANDOM % 3 + 3))
    local selected_fonts=()
    local temp_fonts=("${FONTS_LIST[@]}")
    
    for ((i=0; i<num_fonts; i++)); do
        if [[ ${#temp_fonts[@]} -eq 0 ]]; then break; fi
        
        local idx=$((RANDOM % ${#temp_fonts[@]}))
        selected_fonts+=("${temp_fonts[idx]}")
        
        # Remove selected font from temp array
        temp_fonts=("${temp_fonts[@]:0:idx}" "${temp_fonts[@]:$((idx+1))}")
    done
    
    log "🎯 Selected fonts for machine $machine_id: ${selected_fonts[*]}"
    
    # Install selected fonts
    sudo apt update
    sudo apt install -y "${selected_fonts[@]}"
    
    # Install additional font packages for Ubuntu 24.04
    sudo apt install -y fonts-noto-color-emoji fonts-noto-cjk fonts-noto-cjk-extra
    
    # Update font cache
    fc-cache -fv
    
    log "✅ Random fonts installed successfully"
}

# === RANDOM AUDIO CONFIGURATION ===
configure_random_audio() {
    log "🔊 Configuring random audio theme for this machine..."
    
    local machine_id
    machine_id=$(generate_machine_id)
    
    # Use machine ID as seed for consistent randomization
    local seed=$((0x${machine_id:0:8}))
    RANDOM=$seed
    
    # Select random audio theme
    local audio_theme="${AUDIO_THEMES[$((RANDOM % ${#AUDIO_THEMES[@]}))]}"
    log "🎵 Selected audio theme for machine $machine_id: $audio_theme"
    
    # Install audio packages for Ubuntu 24.04
    sudo apt install -y pulseaudio pulseaudio-utils alsa-utils sound-theme-freedesktop
    
    # Install additional audio themes
    sudo apt install -y ubuntu-sounds gnome-audio sound-icons
    
    # Configure audio theme based on desktop environment
    case $DESKTOP_ENV in
        "GNOME"|"Unity")
            gsettings set org.gnome.desktop.sound theme-name "$audio_theme" 2>/dev/null || true
            gsettings set org.gnome.desktop.sound event-sounds true 2>/dev/null || true
            ;;
        "LXQt"|"LXDE"|"Lubuntu")
            # Configure for LXQt/LXDE
            mkdir -p ~/.config/lxqt
            echo "theme=$audio_theme" >> ~/.config/lxqt/lxqt.conf 2>/dev/null || true
            ;;
        "XFCE")
            # Configure for XFCE
            xfconf-query -c xsettings -p /Net/SoundThemeName -s "$audio_theme" 2>/dev/null || true
            xfconf-query -c xsettings -p /Net/EnableEventSounds -s true 2>/dev/null || true
            ;;
    esac
    
    # Set random volume level (60-85%)
    local volume=$((RANDOM % 26 + 60))
    pactl set-sink-volume @DEFAULT_SINK@ ${volume}% 2>/dev/null || true
    
    log "✅ Audio configuration completed (Theme: $audio_theme, Volume: ${volume}%)"
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

    # Install dependencies for Ubuntu 24.04
    sudo apt update
    sudo apt install -y wget gnupg software-properties-common apt-transport-https ca-certificates curl

    # Add Chrome repository for Ubuntu 24.04
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - 2>/dev/null || true
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

    # Install Chrome package
    sudo dpkg -i "$chrome_file" || sudo apt install -f -y

    # Fix any dependency issues for Ubuntu 24.04
    sudo apt update && sudo apt install -f -y

    log "✅ Chrome installation completed"
}

install_firefox() {
    local firefox_file="$1"

    log "🔧 Installing Firefox from: $firefox_file"

    # Install dependencies for Ubuntu 24.04
    sudo apt update
    sudo apt install -y wget software-properties-common curl

    # For Ubuntu 24.04, prefer snap installation for better compatibility
    if [[ "$firefox_file" == "snap_installed" ]]; then
        log "✅ Firefox already installed via snap"
        return 0
    fi

    # Install Firefox package
    sudo dpkg -i "$firefox_file" || {
        log "📦 Falling back to snap installation..."
        sudo snap install firefox
        return 0
    }

    # Fix any dependency issues for Ubuntu 24.04
    sudo apt install -f -y

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
Exec=/usr/bin/google-chrome-stable --password-store=basic %U
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

# === PASSWORD ISSUES FIX ===
fix_password_issues() {
    log "🔧 Fixing all password issues..."

    # 1. Remove password for current user
    log "🔓 Removing user password..."
    sudo passwd -d $USER

    # 2. Configure sudo without password
    log "⚡ Configuring sudo without password..."
    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER

    # 3. Configure auto-login based on desktop environment and Ubuntu version
    detect_desktop_environment
    
    case $DESKTOP_ENV in
        "LXQt"|"LXDE"|"Lubuntu")
            log "🚀 Configuring auto-login for LightDM (Lubuntu 24.04)..."
            sudo mkdir -p /etc/lightdm/lightdm.conf.d
            
            # Ubuntu 24.04 LXQt session name
            local session_name="lxqt"
            if [[ "$DESKTOP_ENV" == "LXDE" ]]; then
                session_name="LXDE"
            elif [[ "$DESKTOP_ENV" == "Lubuntu" ]]; then
                session_name="Lubuntu"
            fi
            
            sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf << EOF
[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
autologin-session=$session_name
user-session=$session_name
EOF
            ;;
            
        "GNOME"|"Unity"|*)
            log "🚀 Configuring auto-login for GDM3 (Ubuntu 24.04)..."
            sudo tee /etc/gdm3/custom.conf << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$USER
WaylandEnable=false

[security]

[xdmcp]

[chooser]

[debug]
EOF
            ;;
    esac

    # 5. Disable GNOME Keyring completely
    log "🔑 Disabling GNOME Keyring..."
    sudo apt remove --purge -y gnome-keyring seahorse 2>/dev/null || true
    sudo apt remove --purge -y kwalletmanager kwallet-kf5 2>/dev/null || true

    # 6. Remove all keyring data
    log "🗑️ Removing keyring data..."
    rm -rf ~/.local/share/keyrings 2>/dev/null || true
    rm -rf ~/.gnupg 2>/dev/null || true
    rm -rf ~/.config/kwalletrc 2>/dev/null || true

    # 7. Disable PAM keyring
    log "🔒 Disabling PAM keyring..."
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/login 2>/dev/null || true
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/passwd 2>/dev/null || true
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-password 2>/dev/null || true
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-autologin 2>/dev/null || true

    # 8. Disable PolicyKit password prompts
    log "🛡️ Disabling PolicyKit prompts..."
    sudo mkdir -p /etc/polkit-1/localauthority/50-local.d
    sudo tee /etc/polkit-1/localauthority/50-local.d/disable-passwords.pkla << EOF
[Disable password prompts for $USER]
Identity=unix-user:$USER
Action=*
ResultActive=yes
ResultInactive=yes
ResultAny=yes
EOF

    # 9. Configure Chrome without password requirements
    log "🌐 Configuring Chrome..."
    mkdir -p ~/.config/google-chrome/Default
    cat > ~/.config/google-chrome/Default/Preferences << 'EOF'
{
   "profile": {
      "password_manager_enabled": false,
      "default_content_setting_values": {
         "password_manager": 2
      }
   }
}
EOF

    # 10. Configure Firefox without password requirements
    log "🦊 Configuring Firefox..."
    # Create Firefox profile if not exists
    firefox -CreateProfile "default" 2>/dev/null || true
    sleep 2
    pkill firefox 2>/dev/null || true

    # Find Firefox profile directory
    FF_PROFILE=$(find ~/.mozilla/firefox -name "*.default*" -type d 2>/dev/null | head -n 1)
    if [[ -n "$FF_PROFILE" ]]; then
        cat > "$FF_PROFILE/user.js" << 'EOF'
user_pref("security.ask_for_password", 0);
user_pref("security.password_lifetime", 9999);
user_pref("signon.rememberSignons", false);
user_pref("security.default_personal_cert", "");
EOF
    fi

    # 11. Disable systemd user services that may cause prompts
    log "⚙️ Disabling unnecessary services..."
    systemctl --user disable gnome-keyring-daemon 2>/dev/null || true
    systemctl --user stop gnome-keyring-daemon 2>/dev/null || true

    log "✅ Password issues fixed!"
    log "🔄 REBOOT REQUIRED to apply changes"
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
    
    # Configure random fonts and audio for this machine
    install_random_fonts
    configure_random_audio
}

# === FULL SETUP WITH PASSWORD FIX ===
install_full_setup_with_password_fix() {
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

    # Install random fonts and configure audio
    install_random_fonts
    configure_random_audio

    # Fix all password issues
    fix_password_issues

    # Prompt for reboot
    echo ""
    echo "✅ INSTALLATION COMPLETED!"
    echo ""
    echo "🎨 Random fonts and audio configured for this machine"
    echo "🔄 REBOOT REQUIRED to apply all changes:"
    echo "   sudo reboot"
    echo ""
    echo "📋 After reboot:"
    echo "   ✅ Auto-login to desktop (no password required)"
    echo "   ✅ Sudo commands work without password"
    echo "   ✅ Chrome/Firefox open without master password prompts"
    echo "   ✅ Unique fonts and audio theme applied"
    echo ""
    read -p "🔄 Reboot now? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
}

# === MAIN MENU ===
show_main_menu() {
    clear
    echo "=============================================="
    echo "  BROWSER & NEKOBOX INSTALLER"
    echo "  Ubuntu/Lubuntu 24.04 Edition"
    echo "=============================================="
    echo "🆔 Machine ID: $(generate_machine_id)"
    echo "🖥️ Desktop: $DESKTOP_ENV | 🐧 Version: $UBUNTU_VERSION"
    echo ""
    echo "Choose an option:"

    select option in "Install Chrome only" "Install Firefox only" "Install Nekobox only" "Full Setup (Browser + Nekobox)" "Full Setup + Fix Password Issues" "Fix Password Issues only" "Configure Random Fonts & Audio" "Exit"; do
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
            "Full Setup + Fix Password Issues")
                install_full_setup_with_password_fix
                break
                ;;
            "Fix Password Issues only")
                fix_password_issues
                echo ""
                echo "✅ PASSWORD ISSUES FIXED!"
                echo ""
                echo "🔄 REBOOT REQUIRED to apply changes:"
                echo "   sudo reboot"
                echo ""
                read -p "🔄 Reboot now? (y/n): " -r
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sudo reboot
                fi
                break
                ;;
            "Configure Random Fonts & Audio")
                detect_desktop_environment
                install_random_fonts
                configure_random_audio
                echo ""
                echo "✅ FONTS & AUDIO CONFIGURED!"
                echo ""
                echo "🎨 Random fonts and audio theme applied for this machine"
                echo "🔄 Logout/Login recommended to see font changes"
                echo ""
                read -p "Press Enter to continue..."
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

    log "🚀 Starting Browser & Nekobox Installer for Ubuntu/Lubuntu 24.04..."

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root!"
        exit 1
    fi

    # Check Ubuntu version compatibility
    if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
        log "⚠️ Warning: This script is optimized for Ubuntu 24.04, detected: $UBUNTU_VERSION"
        read -p "Continue anyway? (y/n): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check internet connection
    if ! ping -c 1 google.com &> /dev/null; then
        echo "❌ No internet connection detected!"
        exit 1
    fi

    # Detect desktop environment
    detect_desktop_environment

    # Show main menu
    while true; do
        show_main_menu
        echo ""
        read -p "Press Enter to return to main menu or Ctrl+C to exit..."
    done
}

# Run main function
main "$@"
