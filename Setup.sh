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
NEKOBOX_DRIVE_ID="1CCercfKCc9W6xFFNxtyhGaVv0M3jdzd_"

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
    # Send logs to stderr to avoid polluting stdout of functions that 'echo' return values
    echo "$message" >&2
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
    # Completely silent operation - redirect ALL output to /dev/null
    local file_list=""
    local temp_dir="/tmp/chrome_list_$$"

    # Try multiple approaches to get the actual file list

    # Approach 1: Use gdown folder with minimal download
    mkdir -p "$temp_dir" >/dev/null 2>&1 && cd "$temp_dir" >/dev/null 2>&1

    # Try to get file listing with very short timeout first - show output for debugging
    if timeout 45 gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies; then
        # Look for any .deb files that were downloaded or listed
        file_list=$(find "$temp_dir" -name "*.deb" -exec basename {} \; 2>/dev/null | sort -V)

        if [[ -n "$file_list" ]]; then
            rm -rf "$temp_dir" >/dev/null 2>&1
            echo "$file_list"
            return 0
        fi
    fi

    # Approach 2: Try with different gdown parameters
    rm -rf "$temp_dir" >/dev/null 2>&1
    mkdir -p "$temp_dir" >/dev/null 2>&1 && cd "$temp_dir" >/dev/null 2>&1

    if timeout 60 gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies --remaining-ok; then
        file_list=$(find "$temp_dir" -type f -name "*.deb" -exec basename {} \; 2>/dev/null | sort -V)

        if [[ -n "$file_list" ]]; then
            rm -rf "$temp_dir" >/dev/null 2>&1
            echo "$file_list"
            return 0
        fi
    fi

    # Clean up
    rm -rf "$temp_dir" >/dev/null 2>&1

    # Return empty if failed
    echo ""
}

select_chrome_version() {
    echo "=============================================="
    echo "  🌐 CHROME VERSION SELECTION"
    echo "=============================================="

    echo ""
    echo "Chọn chế độ cài đặt Chrome:"
    echo ""
    local mode_options=(
        "Tải bản mới nhất từ Google (Khuyến nghị)"
        "Chọn phiên bản từ Google Drive"
    )

    select mode in "${mode_options[@]}"; do
        case $mode in
            "Tải bản mới nhất từ Google (Khuyến nghị)")
                log "🌐 User selected: Download Latest Chrome from official source"
                echo "latest"
                return 0
                ;;
            "Chọn phiên bản từ Google Drive")
                log "📁 User selected: Choose version from Google Drive"
                # Chuẩn bị môi trường Python/gdown chỉ khi cần dùng Google Drive
                setup_python_env
                break
                ;;
            *)
                echo "❌ Lựa chọn không hợp lệ, vui lòng chọn 1 hoặc 2."
                ;;
        esac
    done

    # Chỉ khi chọn Google Drive mới tiến hành lấy danh sách phiên bản
    log "🔍 Checking Google Drive for Chrome versions..."

    local file_list
    file_list=$(get_chrome_file_list)

    if [[ -n "$file_list" ]]; then
        log "✅ Successfully found Chrome files in Google Drive"
        echo ""
        echo "📁 Available Chrome versions in your Google Drive folder:"
        echo ""

        local options=()
        local file_count=0
        while IFS= read -r file; do
            if [[ -n "$file" ]]; then
                options+=("$file")
                file_count=$((file_count + 1))
                echo "   📦 $file"
            fi
        done <<< "$file_list"

        echo ""
        echo "📊 Found $file_count Chrome versions in your Drive folder"
        echo ""
        echo "Choose Chrome version to install:"
        echo ""

        select version in "${options[@]}"; do
            if [[ -n "$version" ]]; then
                log "📦 User selected: $version"
                echo "$version"
                return 0
            else
                echo "❌ Lựa chọn không hợp lệ, vui lòng chọn số trong danh sách."
            fi
        done
    else
        # Không lấy được danh sách từ Drive
        log "⚠️ Could not retrieve file list from Drive folder"
        log "💡 This might be due to network issues or Drive permissions"
        echo ""
        echo "⚠️ Could not access files in Google Drive folder"
        echo "📡 This might be due to:"
        echo "   • Network connectivity issues"
        echo "   • Google Drive folder permissions"
        echo "   • Folder ID incorrect"
        echo ""
        echo "❌ Unable to list Google Drive folder. Aborting installation."
        echo "Please check network, folder permissions, or CHROME_DRIVE_ID and try again."
        log "❌ Aborting: Google Drive listing required for version selection"
        exit 1
    fi
}

# === CHROME DOWNLOAD & INSTALLATION ===
download_latest_chrome() {
    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    log "📥 Downloading latest Chrome from official source..."

    # Download with proper error checking
    if wget -q -O chrome-latest.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"; then
        # Verify the file was downloaded and has reasonable size (>50MB)
        if [[ -f "chrome-latest.deb" ]]; then
            local file_size
            file_size=$(wc -c < "chrome-latest.deb" 2>/dev/null || echo "0")

            if [[ "$file_size" -gt 50000000 ]]; then
                log "✅ Successfully downloaded Chrome ($(du -h chrome-latest.deb | cut -f1))"
                echo "$DOWNLOAD_DIR/chrome-latest.deb"
                return 0
            else
                log "❌ Downloaded file is too small ($file_size bytes)"
                rm -f chrome-latest.deb 2>/dev/null
                return 1
            fi
        else
            log "❌ Downloaded file not found"
            return 1
        fi
    else
        log "❌ Failed to download Chrome from official source"
        rm -f chrome-latest.deb 2>/dev/null
        return 1
    fi
}

download_specific_chrome_file() {
    local version="$1"

    if [[ $version == "latest" ]]; then
        local latest_file
        latest_file=$(download_latest_chrome)
        if [[ $? -eq 0 && -n "$latest_file" ]]; then
            echo "$latest_file"
            return 0
        else
            log "❌ Failed to download latest Chrome"
            return 1
        fi
    fi

    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

    log "📥 Downloading Chrome: $version from Google Drive..."

    # Try to download the entire folder with longer timeout for large files
    log "⏳ This may take a few minutes for large files (100MB+)..."
    if timeout 600 gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies; then
        # Find the specific file (exact name match)
        local downloaded_file
        downloaded_file=$(find "$DOWNLOAD_DIR" -name "$version" | head -n 1)

        if [[ -n "$downloaded_file" && -f "$downloaded_file" ]]; then
            log "✅ Successfully downloaded: $version"
            echo "$downloaded_file"
            return 0
        else
            log "❌ File $version not found in downloaded folder"
        fi
    else
        log "❌ Failed to download from Google Drive (timeout or network error)"
    fi

    # Do not fallback to latest; require Drive file when selected
    log "❌ Drive download failed and fallback is disabled. Aborting."
    return 1
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
    setup_nekobox_integration
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

# === CHROME TASKBAR & DEFAULT BROWSER ===
setup_chrome_integration() {
    log "📌 Setting up Chrome integration..."

    # Set Chrome as default browser
    if command -v xdg-settings &> /dev/null; then
        xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null || true
        log "✅ Chrome set as default browser"
    fi

    # Pin Chrome to taskbar based on desktop environment
    case $DESKTOP_ENV in
        "GNOME"|"Unity")
            # Pin to GNOME dock/favorites
            if command -v gsettings &> /dev/null; then
                local current_favorites
                current_favorites=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo "[]")

                # Add Chrome to favorites if not already there
                if [[ "$current_favorites" != *"google-chrome.desktop"* ]]; then
                    # Remove closing bracket and add Chrome
                    local new_favorites="${current_favorites%]}, 'google-chrome.desktop']"
                    gsettings set org.gnome.shell favorite-apps "$new_favorites" 2>/dev/null || true
                    log "✅ Chrome pinned to GNOME dock"
                fi
            fi
            ;;

        "LXQt"|"LXDE"|"Lubuntu")
            # Pin to LXQt panel
            local panel_config="$HOME/.config/lxqt/panel.conf"
            if [[ -f "$panel_config" ]]; then
                # Backup original config
                cp "$panel_config" "$panel_config.backup" 2>/dev/null || true

                # Add Chrome to quicklaunch if section exists
                if grep -q "\[quicklaunch\]" "$panel_config" 2>/dev/null; then
                    # Add Chrome to existing quicklaunch
                    if ! grep -q "google-chrome.desktop" "$panel_config" 2>/dev/null; then
                        sed -i '/\[quicklaunch\]/a apps\\1\\desktop=/usr/share/applications/google-chrome.desktop' "$panel_config" 2>/dev/null || true
                        log "✅ Chrome added to LXQt panel"
                    fi
                else
                    # Create quicklaunch section
                    echo "" >> "$panel_config"
                    echo "[quicklaunch]" >> "$panel_config"
                    echo "apps\\1\\desktop=/usr/share/applications/google-chrome.desktop" >> "$panel_config"
                    echo "apps\\size=1" >> "$panel_config"
                    log "✅ Chrome pinned to LXQt panel"
                fi
            fi
            ;;
    esac
}

# === CHROME AUTO-UPDATE BLOCKING ===
block_chrome_updates() {
    log "🛡️ Blocking Chrome auto-updates completely..."

    # Method 1: Disable Google Update Services
    log "🔧 Disabling Google Update services..."
    sudo systemctl stop google-chrome-updater 2>/dev/null || true
    sudo systemctl disable google-chrome-updater 2>/dev/null || true
    sudo systemctl mask google-chrome-updater 2>/dev/null || true

    # Remove Google Update components
    sudo rm -rf /opt/google/chrome/cron 2>/dev/null || true
    sudo rm -f /etc/cron.daily/google-chrome 2>/dev/null || true
    sudo rm -f /etc/cron.hourly/google-chrome 2>/dev/null || true

    # Method 2: Block Update URLs in hosts file
    log "🚫 Blocking Chrome update URLs..."
    sudo cp /etc/hosts /etc/hosts.backup 2>/dev/null || true

    # Add Chrome update blocking entries
    cat << 'EOF' | sudo tee -a /etc/hosts >/dev/null
# Chrome Update Blocking - Added by Setup Script
127.0.0.1 update.googleapis.com
127.0.0.1 clients2.google.com
127.0.0.1 clients.google.com
127.0.0.1 dl.google.com
127.0.0.1 edgedl.me.gvt1.com
127.0.0.1 update.chrome.com
127.0.0.1 chrome-devtools-frontend.appspot.com
127.0.0.1 tools.google.com
127.0.0.1 redirector.gvt1.com
127.0.0.1 www.google.com/chrome/browser/desktop/index.html
EOF

    # Method 3: Hold Chrome package version with apt
    log "🔒 Locking Chrome package version..."
    sudo apt-mark hold google-chrome-stable 2>/dev/null || true

    # Method 4: Remove Chrome repository to prevent updates
    log "📦 Removing Chrome repository..."
    sudo rm -f /etc/apt/sources.list.d/google-chrome.list 2>/dev/null || true
    sudo rm -f /usr/share/keyrings/google-chrome-keyring.gpg 2>/dev/null || true

    # Method 5: Configure Chrome policies to disable updates
    log "⚙️ Configuring Chrome policies..."
    sudo mkdir -p /etc/opt/chrome/policies/managed
    sudo tee /etc/opt/chrome/policies/managed/disable_updates.json >/dev/null << 'EOF'
{
    "AutoUpdateCheckPeriodMinutes": 0,
    "UpdatesSuppressed": {
        "StartHour": 0,
        "StartMinute": 0,
        "DurationMin": 1440
    },
    "ComponentUpdatesEnabled": false,
    "BackgroundModeEnabled": false,
    "DefaultBrowserSettingEnabled": false
}
EOF

    # Method 6: Set file permissions to prevent update
    log "🔐 Setting protective file permissions..."
    sudo chmod 444 /etc/opt/chrome/policies/managed/disable_updates.json 2>/dev/null || true

    # Method 7: Create Chrome launcher script that bypasses update checks
    log "🚀 Creating update-bypass launcher..."
    sudo tee /usr/local/bin/chrome-no-update >/dev/null << 'EOF'
#!/bin/bash
# Chrome launcher with update blocking
export GOOGLE_API_KEY=""
export GOOGLE_DEFAULT_CLIENT_ID=""
export GOOGLE_DEFAULT_CLIENT_SECRET=""
exec /usr/bin/google-chrome-stable --disable-background-networking --disable-background-timer-updates --disable-client-side-phishing-detection --disable-component-update --disable-default-apps --disable-sync --no-default-browser-check --no-first-run --disable-background-mode "$@"
EOF

    sudo chmod +x /usr/local/bin/chrome-no-update

    # Method 8: Update desktop shortcut to use no-update launcher
    log "🖥️ Updating desktop shortcut..."
    sed -i 's|Exec=/usr/bin/google-chrome-stable|Exec=/usr/local/bin/chrome-no-update|g' ~/.local/share/applications/google-chrome.desktop 2>/dev/null || true

    # Method 9: Block update processes
    log "🛑 Creating update process blocker..."
    sudo tee /usr/local/bin/block-chrome-updates >/dev/null << 'EOF'
#!/bin/bash
# Kill any Chrome update processes
while true; do
    pkill -f "GoogleUpdate" 2>/dev/null || true
    pkill -f "chrome.*update" 2>/dev/null || true
    pkill -f "google-chrome.*update" 2>/dev/null || true
    sleep 60
done
EOF

    sudo chmod +x /usr/local/bin/block-chrome-updates

    # Create systemd service for update blocker
    sudo tee /etc/systemd/system/block-chrome-updates.service >/dev/null << 'EOF'
[Unit]
Description=Block Chrome Updates
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/block-chrome-updates
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable block-chrome-updates.service 2>/dev/null || true
    sudo systemctl start block-chrome-updates.service 2>/dev/null || true

    # Method 10: Create verification script
    log "✅ Creating update block verification..."
    tee ~/check-chrome-updates.sh >/dev/null << 'EOF'
#!/bin/bash
echo "=== Chrome Update Block Status ==="
echo "1. Package hold status:"
apt-mark showhold | grep chrome || echo "   No holds found"
echo ""
echo "2. Blocked URLs in hosts:"
grep -c "update.googleapis.com" /etc/hosts || echo "   No blocks found"
echo ""
echo "3. Chrome policies:"
ls -la /etc/opt/chrome/policies/managed/ 2>/dev/null || echo "   No policies found"
echo ""
echo "4. Update blocker service:"
systemctl is-active block-chrome-updates.service 2>/dev/null || echo "   Service not running"
echo ""
echo "5. Chrome version:"
google-chrome-stable --version 2>/dev/null || echo "   Chrome not found"
EOF

    chmod +x ~/check-chrome-updates.sh

    log "✅ Chrome auto-update blocking completed!"
    log "📋 Run ~/check-chrome-updates.sh to verify blocking status"
}

# === CREATE SYSTEM VERIFICATION SCRIPT ===
create_verification_script() {
    log "📋 Creating system verification script..."

    tee ~/check-system-setup.sh >/dev/null << 'EOF'
#!/bin/bash

echo "=============================================="
echo "  🔍 SYSTEM SETUP VERIFICATION"
echo "=============================================="
echo ""

# Machine ID
echo "🆔 Machine ID:"
if [[ -f ~/.machine_id ]]; then
    echo "   $(cat ~/.machine_id)"
else
    echo "   ❌ Machine ID not found"
fi
echo ""

# Random Fonts Check
echo "🎨 Random Fonts Status:"
echo "   Selected fonts for this machine:"
MACHINE_ID=$(cat ~/.machine_id 2>/dev/null || echo "unknown")
echo "   Machine ID: $MACHINE_ID"

echo ""
echo "   Installed font packages:"
dpkg -l | grep -E "fonts-(noto|liberation|dejavu|ubuntu|roboto|open-sans|lato|source-code|fira|cascadia|jetbrains|hack|inconsolata|droid)" | awk '{print "   ✅ " $2}'

echo ""
echo "   Available fonts in system:"
fc-list | grep -E "(Noto|Liberation|DejaVu|Ubuntu|Roboto|Open Sans|Lato|Source Code|Fira|Cascadia|JetBrains|Hack|Inconsolata|Droid)" | wc -l | awk '{print "   📊 Total fonts available: " $1}'

echo ""

# Random Audio Check
echo "🔊 Random Audio Status:"
DESKTOP_ENV=""
if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
    DESKTOP_ENV="$DESKTOP_SESSION"
fi

case "$DESKTOP_ENV" in
    *"GNOME"*|*"gnome"*)
        echo "   Desktop: GNOME"
        AUDIO_THEME=$(gsettings get org.gnome.desktop.sound theme-name 2>/dev/null || echo "not-set")
        echo "   Audio theme: $AUDIO_THEME"
        SOUND_ENABLED=$(gsettings get org.gnome.desktop.sound event-sounds 2>/dev/null || echo "not-set")
        echo "   Sound events: $SOUND_ENABLED"
        ;;
    *"LXQt"*|*"lxqt"*|*"Lubuntu"*)
        echo "   Desktop: LXQt/Lubuntu"
        if [[ -f ~/.config/lxqt/lxqt.conf ]]; then
            AUDIO_THEME=$(grep "theme=" ~/.config/lxqt/lxqt.conf 2>/dev/null | cut -d'=' -f2 || echo "not-set")
            echo "   Audio theme: $AUDIO_THEME"
        else
            echo "   ❌ LXQt config not found"
        fi
        ;;
    *)
        echo "   Desktop: $DESKTOP_ENV"
        echo "   ⚠️ Audio theme detection not supported for this desktop"
        ;;
esac

# Volume check
VOLUME=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1 || echo "unknown")
echo "   Current volume: $VOLUME"

echo ""

# Audio packages check
echo "   Installed audio packages:"
dpkg -l | grep -E "(pulseaudio|alsa-utils|ubuntu-sounds|gnome-audio|sound-)" | awk '{print "   ✅ " $2}'

echo ""

# Chrome Status
echo "🌐 Chrome Status:"
if command -v google-chrome-stable &> /dev/null; then
    CHROME_VERSION=$(google-chrome-stable --version 2>/dev/null)
    echo "   ✅ $CHROME_VERSION"

    # Check if Chrome is default browser
    DEFAULT_BROWSER=$(xdg-settings get default-web-browser 2>/dev/null || echo "unknown")
    echo "   Default browser: $DEFAULT_BROWSER"

    # Check update blocking
    UPDATE_BLOCKS=$(grep -c "update.googleapis.com" /etc/hosts 2>/dev/null || echo "0")
    echo "   Update blocks in hosts: $UPDATE_BLOCKS"

    PACKAGE_HOLD=$(apt-mark showhold | grep chrome | wc -l)
    echo "   Package holds: $PACKAGE_HOLD"
else
    echo "   ❌ Chrome not installed"
fi

echo ""

# NekoBox Status
echo "🔧 NekoBox Status:"
if [[ -f /usr/local/bin/nekobox ]]; then
    echo "   ✅ NekoBox installed at /usr/local/bin/nekobox"

    # Check autostart
    if [[ -f ~/.config/autostart/nekobox.desktop ]]; then
        echo "   ✅ Autostart configured"
    else
        echo "   ❌ Autostart not configured"
    fi

    # Check if running
    if pgrep -f nekobox > /dev/null; then
        echo "   ✅ NekoBox is running"
    else
        echo "   ⚠️ NekoBox is not running"
    fi
else
    echo "   ❌ NekoBox not installed"
fi

echo ""

# Password-free status
echo "🔐 Password-free Status:"
if sudo -n true 2>/dev/null; then
    echo "   ✅ Sudo works without password"
else
    echo "   ❌ Sudo still requires password"
fi

# Check auto-login
if [[ -f /etc/lightdm/lightdm.conf.d/50-autologin.conf ]] || [[ -f /etc/gdm3/custom.conf ]]; then
    echo "   ✅ Auto-login configured"
else
    echo "   ❌ Auto-login not configured"
fi

echo ""
echo "=============================================="
echo "  📊 VERIFICATION COMPLETE"
echo "=============================================="
echo ""
echo "💡 Tips:"
echo "   • Test fonts: Open LibreOffice and check font list"
echo "   • Test audio: Run 'paplay /usr/share/sounds/alsa/Front_Left.wav'"
echo "   • Check Chrome updates: Run '~/check-chrome-updates.sh'"
echo ""
EOF

    chmod +x ~/check-system-setup.sh
    log "✅ Verification script created: ~/check-system-setup.sh"
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

# === NEKOBOX AUTOSTART & TASKBAR ===
setup_nekobox_integration() {
    log "🚀 Setting up NekoBox integration..."

    # Create autostart entry
    mkdir -p ~/.config/autostart
    cat > ~/.config/autostart/nekobox.desktop << EOF
[Desktop Entry]
Version=1.0
Name=NekoBox
Comment=Proxy client - Auto start
Exec=/usr/local/bin/nekobox
Icon=nekobox
Terminal=false
Type=Application
Categories=Network;
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
EOF

    chmod +x ~/.config/autostart/nekobox.desktop
    log "✅ NekoBox autostart configured"

    # Pin NekoBox to taskbar based on desktop environment
    case $DESKTOP_ENV in
        "GNOME"|"Unity")
            # Pin to GNOME dock/favorites
            if command -v gsettings &> /dev/null; then
                local current_favorites
                current_favorites=$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo "[]")

                # Add NekoBox to favorites if not already there
                if [[ "$current_favorites" != *"nekobox.desktop"* ]]; then
                    # Remove closing bracket and add NekoBox
                    local new_favorites="${current_favorites%]}, 'nekobox.desktop']"
                    gsettings set org.gnome.shell favorite-apps "$new_favorites" 2>/dev/null || true
                    log "✅ NekoBox pinned to GNOME dock"
                fi
            fi
            ;;

        "LXQt"|"LXDE"|"Lubuntu")
            # Pin to LXQt panel
            local panel_config="$HOME/.config/lxqt/panel.conf"
            if [[ -f "$panel_config" ]]; then
                # Add NekoBox to quicklaunch
                if grep -q "\[quicklaunch\]" "$panel_config" 2>/dev/null; then
                    # Add NekoBox to existing quicklaunch
                    if ! grep -q "nekobox.desktop" "$panel_config" 2>/dev/null; then
                        # Count existing apps and add NekoBox
                        local app_count=$(grep -c "apps\\\\.*\\\\desktop=" "$panel_config" 2>/dev/null || echo "0")
                        local next_num=$((app_count + 1))
                        sed -i "/\[quicklaunch\]/a apps\\\\${next_num}\\\\desktop=$HOME/.local/share/applications/nekobox.desktop" "$panel_config" 2>/dev/null || true
                        sed -i "s/apps\\\\size=.*/apps\\\\size=${next_num}/" "$panel_config" 2>/dev/null || true
                        log "✅ NekoBox added to LXQt panel"
                    fi
                else
                    # Create quicklaunch section with NekoBox
                    echo "" >> "$panel_config"
                    echo "[quicklaunch]" >> "$panel_config"
                    echo "apps\\1\\desktop=$HOME/.local/share/applications/nekobox.desktop" >> "$panel_config"
                    echo "apps\\size=1" >> "$panel_config"
                    log "✅ NekoBox pinned to LXQt panel"
                fi
            fi
            ;;
    esac

    # Create system tray configuration for NekoBox
    mkdir -p ~/.config/nekobox 2>/dev/null || true
    cat > ~/.config/nekobox/config.json << 'EOF' 2>/dev/null || true
{
    "start_minimized": true,
    "minimize_to_tray": true,
    "close_to_tray": true,
    "auto_start": true
}
EOF

    log "✅ NekoBox system tray configured"
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
    echo "   ✅ Google Chrome (with version selection + pin to taskbar + block updates)"
    echo "   ✅ Nekobox proxy client (with autostart + pin to taskbar)"
    echo "   ✅ Random fonts & audio theme"
    echo "   ✅ Password-free system setup"
    echo ""
    echo "🆔 Machine ID: $(generate_machine_id)"
    echo "🖥️ Desktop: $DESKTOP_ENV | 🐧 Version: $UBUNTU_VERSION"
    echo ""


    # Step 1: Remove existing Chrome
    log "🧹 Step 1/6: Removing existing Chrome installations..."
    remove_existing_chrome

    # Step 2: Select and install Chrome
    log "🌐 Step 2/6: Installing Google Chrome..."

    local version_choice
    version_choice=$(select_chrome_version)

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
    setup_chrome_integration
    block_chrome_updates

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

    # Step 6: Create verification script
    create_verification_script

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
    echo "   ✅ Chrome pinned to taskbar & NEVER auto-updates"
    echo "   ✅ NekoBox auto-starts & pinned to taskbar"
    echo "   ✅ Unique fonts and audio theme applied"
    echo ""
    echo "🛡️ Chrome Update Blocking:"
    echo "   ✅ 10-layer protection against auto-updates"
    echo "   ✅ Run ~/check-chrome-updates.sh to verify status"
    echo ""
    echo "🔍 System Verification:"
    echo "   ✅ Run ~/check-system-setup.sh to check all features"
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
