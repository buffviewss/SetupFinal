#!/bin/bash

# ===================================
# CHROME & NEKOBOX AUTO INSTALLER
# Ubuntu/Lubuntu 24.04 - Full Setup Edition
# Auto runs: Chrome + Nekobox + Fonts + Audio + Password Fix
# ===================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="$HOME/Downloads/browser_setup"
LOG_FILE="$HOME/setup_$(date +%Y%m%d_%H%M%S).log"
MACHINE_ID_FILE="$HOME/.machine_id"

# Google Drive folder IDs
CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
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
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE" 2>/dev/null || true
}

# === SYSTEM DETECTION ===
detect_desktop_environment() {
    # Enhanced detection for Ubuntu/Lubuntu 24.04
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        DESKTOP_ENV="$DESKTOP_SESSION"
    elif pgrep -x "lxqt-session" > /dev/null; then
        DESKTOP_ENV="LXQt"
    elif pgrep -x "lxsession" > /dev/null; then
        DESKTOP_ENV="LXDE"
    elif pgrep -x "gnome-session" > /dev/null; then
        DESKTOP_ENV="GNOME"
    elif pgrep -x "xfce4-session" > /dev/null; then
        DESKTOP_ENV="XFCE"
    elif [[ -f "/usr/bin/lxqt-session" ]]; then
        DESKTOP_ENV="LXQt"
    elif [[ -f "/usr/bin/gnome-session" ]]; then
        DESKTOP_ENV="GNOME"
    else
        DESKTOP_ENV="Unknown"
    fi
    
    # Normalize desktop environment names for Ubuntu/Lubuntu 24.04
    case "$DESKTOP_ENV" in
        "ubuntu:GNOME"|"GNOME"|"gnome") DESKTOP_ENV="GNOME";;
        "LXQt"|"lxqt"|"Lubuntu") DESKTOP_ENV="LXQt";;
        "LXDE"|"lxde") DESKTOP_ENV="LXDE";;
        "XFCE"|"xfce"|"XFCE4") DESKTOP_ENV="XFCE";;
    esac
    
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

# === SYSTEM PREPARATION ===
prepare_system() {
    log "🔧 Preparing system for Ubuntu/Lubuntu 24.04..."
    
    # Update package lists
    sudo apt update
    
    # Install essential packages for Ubuntu 24.04
    sudo apt install -y \
        wget curl gnupg software-properties-common \
        apt-transport-https ca-certificates \
        python3 python3-pip python3-venv \
        build-essential git unzip \
        lsb-release
    
    # Fix any broken packages
    sudo apt --fix-broken install -y
    
    log "✅ System preparation completed"
}

# === RANDOM FONT SELECTION ===
install_random_fonts() {
    log "🎨 Installing random fonts for this machine..."
    
    local machine_id
    machine_id=$(generate_machine_id)
    
    # Use machine ID as seed for consistent randomization
    local seed=$((0x${machine_id:0:8}))
    RANDOM=$seed
    
    # Select 4-6 random fonts
    local num_fonts=$((RANDOM % 3 + 4))
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
    
    # Set random volume level (65-80%)
    local volume=$((RANDOM % 16 + 65))
    pactl set-sink-volume @DEFAULT_SINK@ ${volume}% 2>/dev/null || true
    
    log "✅ Audio configuration completed (Theme: $audio_theme, Volume: ${volume}%)"
}

# === PYTHON ENVIRONMENT SETUP ===
setup_python_env() {
    log "🐍 Setting up Python environment for Ubuntu 24.04..."

    # Install Python and pip if not available
    if ! command -v python3 &> /dev/null; then
        sudo apt update && sudo apt install -y python3 python3-pip python3-venv
    fi

    # For Ubuntu 24.04, use virtual environment (best practice)
    if [[ ! -d "$HOME/.local/venv" ]]; then
        python3 -m venv "$HOME/.local/venv"
    fi
    
    # Activate virtual environment and install gdown
    source "$HOME/.local/venv/bin/activate"
    pip install --upgrade pip
    pip install gdown
    
    # Create wrapper script for gdown
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/gdown" << 'EOF'
#!/bin/bash
source "$HOME/.local/venv/bin/activate"
exec python -m gdown "$@"
EOF
    chmod +x "$HOME/.local/bin/gdown"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
    
    log "✅ Python environment setup completed"
}

# === CHROME VERSION SELECTION ===
get_chrome_file_list() {
    log "🔍 Getting Chrome file list from Google Drive..."

    # Create temp directory for listing files
    local temp_dir="/tmp/chrome_list_$$"
    mkdir -p "$temp_dir" && cd "$temp_dir"

    # Download folder to get file list (with timeout for Ubuntu 24.04)
    timeout 120 gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies --quiet 2>/dev/null || {
        echo "❌ Failed to get Chrome file list from Drive (timeout or network error)"
        rm -rf "$temp_dir"
        return 1
    }

    # Get ALL files in the folder
    local file_list
    file_list=$(find "$temp_dir" -type f -exec basename {} \; | sort)

    # Clean up temp directory
    rm -rf "$temp_dir"

    echo "$file_list"
}

select_chrome_version() {
    echo "=============================================="
    echo "  🌐 CHROME VERSION SELECTION"
    echo "=============================================="
    
    local file_list
    file_list=$(get_chrome_file_list)

    if [[ -z "$file_list" ]]; then
        log "⚠️ Could not retrieve Chrome file list, using latest version"
        echo "latest"
        return 0
    fi

    echo "Choose Chrome version to install:"
    echo ""

    # Add download latest option
    local options=("Download Latest Chrome (Recommended)")

    # Add ALL files from drive
    while IFS= read -r file; do
        [[ -n "$file" ]] && options+=("$file")
    done <<< "$file_list"

    select version in "${options[@]}"; do
        case $version in
            "Download Latest Chrome (Recommended)") echo "latest"; return 0;;
            *)
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return 0
                else
                    echo "❌ Invalid option! Using latest version..."
                    echo "latest"
                    return 0
                fi
                ;;
        esac
    done
}

# === CHROME DOWNLOAD & INSTALLATION ===
download_latest_chrome() {
    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    log "📥 Downloading latest Chrome from official source..."
    wget -O chrome-latest.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    echo "$DOWNLOAD_DIR/chrome-latest.deb"
}

download_specific_chrome_file() {
    local version="$1"

    if [[ $version == "latest" ]]; then
        download_latest_chrome
        return 0
    fi

    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    log "📥 Downloading Chrome: $version..."

    # Download entire folder (with timeout for Ubuntu 24.04)
    timeout 300 gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies

    # Find the specific file (exact name match)
    local downloaded_file
    downloaded_file=$(find "$DOWNLOAD_DIR" -name "$version" | head -n 1)

    if [[ -z "$downloaded_file" ]]; then
        log "❌ File $version not found after download, using latest version"
        download_latest_chrome
        return 0
    fi

    echo "$downloaded_file"
}

# === CHROME REMOVAL ===
remove_existing_chrome() {
    log "🗑️ Removing existing Chrome installations..."

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

    # Clean up package cache
    sudo apt autoremove -y 2>/dev/null || true
    sudo apt autoclean 2>/dev/null || true

    log "✅ Chrome removal completed"
}

# === CHROME INSTALLATION ===
install_chrome() {
    local chrome_file="$1"

    log "🔧 Installing Chrome from: $chrome_file"

    # Install dependencies for Ubuntu 24.04
    sudo apt update
    sudo apt install -y wget gnupg software-properties-common apt-transport-https ca-certificates curl

    # Add Chrome repository for Ubuntu 24.04 (using new method, apt-key is deprecated)
    wget -q -O /tmp/google-chrome-key.gpg https://dl.google.com/linux/linux_signing_key.pub
    sudo gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg /tmp/google-chrome-key.gpg 2>/dev/null || true
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    rm -f /tmp/google-chrome-key.gpg

    # Install Chrome package
    sudo dpkg -i "$chrome_file" || sudo apt install -f -y

    # Fix any dependency issues for Ubuntu 24.04
    sudo apt update && sudo apt install -f -y

    log "✅ Chrome installation completed"
}

# === NEKOBOX INSTALLATION ===
install_nekobox() {
    log "🔧 Installing Nekobox..."

    setup_python_env

    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    # Download Nekobox from Google Drive
    log "📥 Downloading Nekobox from Google Drive..."
    timeout 300 gdown --folder "https://drive.google.com/drive/folders/$NEKOBOX_DRIVE_ID" --no-cookies

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
create_chrome_shortcut() {
    mkdir -p ~/.local/share/applications
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

    chmod +x ~/.local/share/applications/google-chrome.desktop
    log "✅ Chrome shortcut created"
}

create_nekobox_shortcut() {
    mkdir -p ~/.local/share/applications
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

    # 4. Disable GNOME Keyring completely
    log "🔑 Disabling GNOME Keyring..."
    sudo apt remove --purge -y gnome-keyring seahorse 2>/dev/null || true
    sudo apt remove --purge -y kwalletmanager kwallet-kf5 2>/dev/null || true

    # 5. Remove all keyring data
    log "🗑️ Removing keyring data..."
    rm -rf ~/.local/share/keyrings 2>/dev/null || true
    rm -rf ~/.gnupg 2>/dev/null || true
    rm -rf ~/.config/kwalletrc 2>/dev/null || true

    # 6. Disable PAM keyring
    log "🔒 Disabling PAM keyring..."
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/login 2>/dev/null || true
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/passwd 2>/dev/null || true
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-password 2>/dev/null || true
    sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-autologin 2>/dev/null || true

    # 7. Disable PolicyKit password prompts
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

    # 8. Configure Chrome without password requirements
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

    # 9. Disable systemd user services that may cause prompts
    log "⚙️ Disabling unnecessary services..."
    systemctl --user disable gnome-keyring-daemon 2>/dev/null || true
    systemctl --user stop gnome-keyring-daemon 2>/dev/null || true

    log "✅ Password issues fixed!"
    log "🔄 REBOOT REQUIRED to apply changes"
}

# === MAIN INSTALLATION FUNCTION ===
install_full_setup() {
    echo ""
    echo "=============================================="
    echo "  🚀 STARTING FULL SETUP INSTALLATION"
    echo "=============================================="
    echo "🎯 This will install:"
    echo "   ✅ Google Chrome (with version selection)"
    echo "   ✅ Nekobox proxy client"
    echo "   ✅ Random fonts & audio theme"
    echo "   ✅ Password-free system setup"
    echo ""
    echo "🆔 Machine ID: $(generate_machine_id)"
    echo "🖥️ Desktop: $DESKTOP_ENV | 🐧 Version: $UBUNTU_VERSION"
    echo ""

    read -p "🔥 Continue with full installation? (y/n): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "❌ Installation cancelled by user"
        exit 0
    fi

    # Step 1: Remove existing Chrome
    log "🧹 Step 1/6: Removing existing Chrome installations..."
    remove_existing_chrome

    # Step 2: Select and install Chrome
    log "🌐 Step 2/6: Installing Google Chrome..."
    local version_choice
    version_choice=$(select_chrome_version)

    setup_python_env

    local selected_file
    selected_file=$(download_specific_chrome_file "$version_choice")

    if [[ -z "$selected_file" || ! -f "$selected_file" ]]; then
        log "❌ Failed to download Chrome installation file"
        exit 1
    fi

    # Clean up unused files (keep only the selected installation file)
    find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$selected_file")" -delete 2>/dev/null || true

    install_chrome "$selected_file"
    create_chrome_shortcut

    # Step 3: Install Nekobox
    log "🔧 Step 3/6: Installing Nekobox..."
    rm -rf "$DOWNLOAD_DIR" 2>/dev/null || true
    install_nekobox

    # Step 4: Configure random fonts and audio
    log "🎨 Step 4/6: Configuring random fonts..."
    install_random_fonts

    log "🔊 Step 5/6: Configuring random audio..."
    configure_random_audio

    # Step 5: Fix all password issues
    log "🔐 Step 6/6: Fixing password issues..."
    fix_password_issues

    # Installation completed
    echo ""
    echo "=============================================="
    echo "  ✅ INSTALLATION COMPLETED SUCCESSFULLY!"
    echo "=============================================="
    echo ""
    echo "🎨 Random fonts and audio configured for this machine"
    echo "🔄 REBOOT REQUIRED to apply all changes:"
    echo "   sudo reboot"
    echo ""
    echo "📋 After reboot you will have:"
    echo "   ✅ Auto-login to desktop (no password required)"
    echo "   ✅ Sudo commands work without password"
    echo "   ✅ Chrome opens without master password prompts"
    echo "   ✅ Nekobox proxy client ready to use"
    echo "   ✅ Unique fonts and audio theme applied"
    echo ""
    read -p "🔄 Reboot now to complete setup? (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        echo ""
        echo "⚠️  Remember to reboot manually to apply all changes:"
        echo "   sudo reboot"
        echo ""
    fi
}

# === MAIN EXECUTION ===
main() {
    # Create log file with proper error handling
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"

    clear
    echo "=============================================="
    echo "  🌐 CHROME & NEKOBOX AUTO INSTALLER"
    echo "  Ubuntu/Lubuntu 24.04 Edition"
    echo "=============================================="
    echo ""

    log "🚀 Starting Chrome & Nekobox Auto Installer for Ubuntu/Lubuntu 24.04..."

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root!"
        echo "Please run as regular user with sudo privileges."
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

    # Check internet connection (multiple methods for Ubuntu 24.04)
    log "🌐 Checking internet connectivity..."
    if ! ping -c 1 -W 5 google.com &> /dev/null && ! ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        echo "❌ No internet connection detected!"
        echo "Please check your network connection and try again."
        exit 1
    fi
    log "✅ Internet connection verified"

    # Detect desktop environment
    detect_desktop_environment

    # Prepare system for Ubuntu 24.04
    prepare_system

    # Run full installation
    install_full_setup
}

# Run main function
main "$@"
