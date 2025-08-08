#!/bin/bash
# Unified setup script (Chrome + Nekobox + optional no-password)
# Ubuntu/Lubuntu 24.04 compatible

set -euo pipefail
IFS=$'\n\t'
export DEBIAN_FRONTEND=noninteractive

# --- Temp workspace ---
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# --- Config (IDs preserved as requested) ---
CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
NEKOBOX_FILE_ID="1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj"
DOWNLOAD_DIR="$HOME/browser_temp"

# --- Utilities ---
ensure_prereqs() {
  echo "📦 Preparing prerequisites..."
  sudo add-apt-repository universe -y || true
  sudo apt update
  sudo apt install -y python3-venv python3-pip unzip || true
  # venv for gdown (shared)
  if [[ ! -d "$HOME/gdown-venv" ]]; then
    python3 -m venv "$HOME/gdown-venv"
  fi
  # shellcheck source=/dev/null
  source "$HOME/gdown-venv/bin/activate"
  pip install --no-cache-dir -U pip gdown
}

# --- Chrome install from Google Drive (Firefox logic removed) ---
install_chrome_from_drive() {
  echo "🌐 Installing Chrome from Google Drive..."
  ensure_prereqs

  mkdir -p "$DOWNLOAD_DIR"
  cd "$DOWNLOAD_DIR"

  echo "📥 Downloading Chrome folder from Google Drive..."
  gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies

  echo "🔍 Listing downloaded .deb files..."
  mapfile -t FILES < <(find "$DOWNLOAD_DIR" -type f -name "*.deb" | sort)
  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "❌ No .deb file found!"
    return 1
  fi

  for i in "${!FILES[@]}"; do
    printf "%2d) %s\n" "$((i+1))" "${FILES[$i]}"
  done
  read -rp "👉 Select file number to install: " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#FILES[@]} )); then
    echo "❌ Invalid choice"; return 1
  fi
  FILE_SELECT="${FILES[$((choice-1))]}"
  echo "✅ Selected: $FILE_SELECT"

  echo "🧹 Cleaning other files..."
  find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$FILE_SELECT")" -delete || true

  echo "🗑️ Removing existing Chrome if any..."
  sudo apt remove -y google-chrome-stable || true

  echo "🚀 Installing Chrome..."
  sudo apt install -y "$FILE_SELECT" || {
    echo "⚠️ Fixing dependencies...";
    sudo apt --fix-broken install -y;
    sudo apt install -y "$FILE_SELECT";
  }

  echo "🔒 Holding Chrome updates via APT..."
  sudo apt-mark hold google-chrome-stable || true
  sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null || true

  echo "🚫 Disabling Chrome internal auto-update..."
  sudo rm -rf /opt/google/chrome/cron/ || true
  sudo mkdir -p /etc/opt/chrome/policies/managed
  cat <<EOF > /tmp/disable_update.json
{
  "AutoUpdateCheckPeriodMinutes": 0,
  "DisableAutoUpdateChecksCheckbox": true,
  "MetricsReportingEnabled": false
}
EOF
  sudo mv /tmp/disable_update.json /etc/opt/chrome/policies/managed/disable_update.json
  sudo chmod -R 000 /opt/google/chrome/cron 2>/dev/null || true

  echo "🎨 Creating application shortcut..."
  mkdir -p ~/.local/share/applications
  cat <<EOF3 > ~/.local/share/applications/browser_custom.desktop
[Desktop Entry]
Name=Google Chrome (Custom)
Exec=/usr/bin/google-chrome-stable %U
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF3

  echo "📌 Pinning to taskbar when supported..."
  if command -v gsettings &>/dev/null; then
    gio set ~/.local/share/applications/browser_custom.desktop metadata::trusted true 2>/dev/null || true
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'browser_custom.desktop']/")" || true
  else
    echo "ℹ️ On Lubuntu (LXQt), right-click the menu entry -> 'Pin to Panel'."
  fi

  echo "✅ Chrome installed, updates locked and auto-update disabled."
}

# --- Nekobox/Nekoray setup (kept largely as original) ---
setup_nekobox() {
  echo "🔄 Updating system packages..."
  sudo add-apt-repository universe -y || true
  sudo apt update && sudo apt upgrade -y || true

  echo "📦 Installing Open VM Tools..."
  sudo apt install -y open-vm-tools open-vm-tools-desktop || echo "⚠️ Warning: Open VM Tools may be unavailable."

  echo "📦 Installing gdown & unzip..."
  sudo apt install -y python3-pip unzip || true
  if ! command -v pip3 &> /dev/null; then
    echo "⚠️ pip3 missing, installing..."
    sudo apt install -y python3-pip
  fi
  sudo apt install -y python3-venv || true
  python3 -m venv "$HOME/venv" || true
  # shellcheck source=/dev/null
  source "$HOME/venv/bin/activate" 2>/dev/null || true
  pip install --upgrade pip gdown || true

  echo "📦 Installing build tools and Qt5 libraries..."
  sudo apt install -y build-essential \
    libqt5network5 libqt5core5a libqt5gui5 libqt5widgets5 \
    qtbase5-dev libqt5x11extras5 libqt5quick5 libqt5quickwidgets5 libqt5quickparticles5 || true

  echo "📂 Preparing Nekoray folder..."
  rm -rf "$HOME/Downloads/nekoray"
  mkdir -p "$HOME/Downloads/nekoray"

  echo "⬇️ Downloading Nekobox from Google Drive..."
  cd "$HOME/Downloads"
  gdown --id "$NEKOBOX_FILE_ID" -O nekobox.zip || { echo "❌ Download failed! Check Google Drive file ID."; return 1; }

  echo "📂 Extracting Nekobox..."
  unzip -o nekobox.zip -d "$HOME/Downloads/nekoray"

  echo "📂 Adjusting folder structure if nested..."
  inner_dir=$(find "$HOME/Downloads/nekoray" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)
  if [[ -n "${inner_dir:-}" && "$inner_dir" != "$HOME/Downloads/nekoray" ]]; then
    mv "$inner_dir"/* "$HOME/Downloads/nekoray/" || true
    rm -rf "$inner_dir"
  fi

  echo "🔑 Setting execution permissions..."
  cd "$HOME/Downloads/nekoray"
  chmod +x launcher nekobox nekobox_core 2>/dev/null || echo "⚠️ Some files not found, skipping chmod."

  echo "🖥️ Creating desktop shortcut..."
  cat <<EOF > "$HOME/Desktop/nekoray.desktop"
[Desktop Entry]
Version=1.0
Name=Nekobox
Comment=Open Nekobox
Exec=$HOME/Downloads/nekoray/nekobox
Icon=$HOME/Downloads/nekoray/nekobox.png
Terminal=false
Type=Application
Categories=Utility;
EOF
  chmod +x "$HOME/Desktop/nekoray.desktop"

  echo "📌 Pinning Nekobox to taskbar (GNOME only)..."
  if echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "GNOME"; then
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'nekoray.desktop']/")" || true
  elif echo "${XDG_CURRENT_DESKTOP:-}" | grep -qi "LXQt"; then
    echo "ℹ️ Lubuntu LXQt detected - pin manually by dragging the desktop shortcut to the panel."
  else
    echo "ℹ️ Unknown desktop environment: ${XDG_CURRENT_DESKTOP:-} - skipping auto pinning."
  fi

  echo "⚙️ Enabling autostart..."
  mkdir -p "$HOME/.config/autostart"
  cp "$HOME/Desktop/nekoray.desktop" "$HOME/.config/autostart/nekoray.desktop"
  chmod +x "$HOME/.config/autostart/nekoray.desktop"

  echo "🚀 Launching Nekobox..."
  ./nekobox || echo "⚠️ Unable to launch Nekobox automatically. Start manually from ~/Downloads/nekoray."

  echo "✅ Nekobox setup completed!"
}

# --- Post-setup checks (kept as original) ---
post_checks() {
  echo ""
  echo "🔍 Running post-setup checks..."

  echo "📦 Checking APT packages..."
  for pkg in open-vm-tools open-vm-tools-desktop python3-pip unzip build-essential qtbase5-dev; do
    if dpkg -l | grep -q "^ii\s*$pkg"; then
      echo "✅ $pkg installed"
    else
      echo "❌ $pkg missing"
    fi
  done

  echo "🐍 Python & pip:"
  python3 --version || true
  pip3 --version || true

  echo "⬇️ Checking gdown..."
  if python3 -m pip show gdown >/dev/null 2>&1; then
    echo "✅ gdown installed"
  else
    echo "❌ gdown missing"
  fi

  echo "📂 Checking Nekoray folder..."
  if [[ -d "$HOME/Downloads/nekoray" ]]; then
    echo "✅ Nekoray folder exists"
  else
    echo "❌ Nekoray folder missing"
  fi

  echo "🖥️ Checking Desktop shortcut..."
  if [[ -f "$HOME/Desktop/nekoray.desktop" ]]; then
    echo "✅ Desktop shortcut exists"
  else
    echo "❌ Desktop shortcut missing"
  fi

  echo "🔎 Post-setup check completed!"
}

# --- Danger zone: keep original "no password" block, invoked only via --no-password ---
danger_no_password_all() {
  echo "🔧 Đang sửa tất cả vấn đề password..."

  # 1. XÓA PASSWORD CỦA USER HIỆN TẠI
  echo "🔓 Xóa password user..."
  sudo passwd -d $USER

  # 2. CẤU HÌNH SUDO KHÔNG CẦN PASSWORD
  echo "⚡ Cấu hình sudo không cần password..."
  echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER

  # 3. CẤU HÌNH AUTO-LOGIN CHO LIGHTDM (LUBUNTU)
  echo "🚀 Cấu hình auto-login cho LightDM..."
  sudo mkdir -p /etc/lightdm/lightdm.conf.d
  sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf << EOF
[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
autologin-session=Lubuntu
EOF

  # 4. CẤU HÌNH AUTO-LOGIN CHO GDM3 (UBUNTU)
  echo "🚀 Cấu hình auto-login cho GDM3..."
  sudo tee /etc/gdm3/custom.conf << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$USER

[security]

[xdmcp]

[chooser]

[debug]
EOF

  # 5. TẮT HOÀN TOÀN GNOME KEYRING
  echo "🔑 Tắt GNOME Keyring..."
  sudo apt remove --purge -y gnome-keyring seahorse 2>/dev/null || true
  sudo apt remove --purge -y kwalletmanager kwallet-kf5 2>/dev/null || true

  # 6. XÓA TẤT CẢ KEYRING DATA
  echo "🗑️ Xóa keyring data..."
  rm -rf ~/.local/share/keyrings 2>/dev/null || true
  rm -rf ~/.gnupg 2>/dev/null || true
  rm -rf ~/.config/kwalletrc 2>/dev/null || true

  # 7. TẮT PAM KEYRING
  echo "🔒 Tắt PAM keyring..."
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/login 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/passwd 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-password 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-autologin 2>/dev/null || true

  # 8. TẮT POLICYKIT PASSWORD PROMPTS
  echo "🛡️ Tắt PolicyKit prompts..."
  sudo mkdir -p /etc/polkit-1/localauthority/50-local.d
  sudo tee /etc/polkit-1/localauthority/50-local.d/disable-passwords.pkla << EOF
[Disable password prompts for $USER]
Identity=unix-user:$USER
Action=*
ResultActive=yes
ResultInactive=yes
ResultAny=yes
EOF

  # 9. CẤU HÌNH CHROME KHÔNG YÊU CẦU PASSWORD
  echo "🌐 Cấu hình Chrome..."
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

  # 10. CẤU HÌNH FIREFOX KHÔNG YÊU CẦU PASSWORD (chỉ cấu hình profile, không cài/ghỡ Firefox)
  echo "🦊 Cấu hình Firefox..."
  firefox -CreateProfile "default" 2>/dev/null || true
  sleep 2
  pkill firefox 2>/dev/null || true
  FF_PROFILE=$(find ~/.mozilla/firefox -name "*.default*" -type d 2>/dev/null | head -n 1)
  if [[ -n "${FF_PROFILE:-}" ]]; then
    cat > "$FF_PROFILE/user.js" << 'EOF'
user_pref("security.ask_for_password", 0);
user_pref("security.password_lifetime", 9999);
user_pref("signon.rememberSignons", false);
user_pref("security.default_personal_cert", "");
EOF
  fi

  # 11. TẮT SYSTEMD USER SERVICES CÓ THỂ GÂY PROMPT
  echo "⚙️ Tắt các service không cần thiết..."
  systemctl --user disable gnome-keyring-daemon 2>/dev/null || true
  systemctl --user stop gnome-keyring-daemon 2>/dev/null || true

  # 12. XÓA CHROME KEYRING INTEGRATION
  echo "🔧 Xóa Chrome keyring integration..."
  sudo rm -f /usr/share/applications/google-chrome.desktop 2>/dev/null || true
  cat > ~/.local/share/applications/google-chrome.desktop << 'EOF'
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

  echo ""
  echo "✅ ĐÃ SỬA TẤT CẢ VẤN ĐỀ!"
  echo ""
  echo "🔄 BẮT BUỘC PHẢI KHỞI ĐỘNG LẠI để áp dụng:"
  echo "   sudo reboot"
  echo ""
  echo "📋 Sau khi reboot:"
  echo "   ✅ Máy tự động vào desktop (không cần password)"
  echo "   ✅ Sudo commands chạy không cần password"
  echo "   ✅ Chrome/Firefox mở không hỏi master password"
}

# --- Menu (optional) ---
show_menu() {
  echo "Chọn tác vụ:"
  select opt in "Cài Chrome" "Cài Nekobox" "Hậu kiểm (post-checks)" "No-password (NGUY HIỂM)" "Thoát"; do
    case $opt in
      "Cài Chrome") install_chrome_from_drive; break;;
      "Cài Nekobox") setup_nekobox; break;;
      "Hậu kiểm (post-checks)") post_checks; break;;
      "No-password (NGUY HIỂM)") danger_no_password_all; break;;
      "Thoát") echo "🚪 Thoát."; break;;
      *) echo "❌ Lựa chọn không hợp lệ!";;
    esac
  done
}

# --- CLI ---
if [[ $# -eq 0 ]]; then
  show_menu
  exit 0
fi

for arg in "$@"; do
  case "$arg" in
    --chrome) install_chrome_from_drive ;;
    --nekobox) setup_nekobox ;;
    --post-checks) post_checks ;;
    --no-password) danger_no_password_all ;;
    --all) install_chrome_from_drive; setup_nekobox; post_checks ;;
    --help|-h) echo "Usage: $0 [--chrome] [--nekobox] [--post-checks] [--no-password] [--all]" ;;
    *) echo "❌ Unknown option: $arg" ;;
  esac
done

