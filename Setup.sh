#!/bin/bash
# All-in-one setup for Ubuntu/Lubuntu 24.04 (AUTO-RUN) — v2 (fix gdown-venv)
# Changes in v2:
#  - Robust ensure_gdown(): verifies python3-venv, recreates broken venv, and falls back to --user install if needed.
#  - PATH exported to include ~/.local/bin so gdown works without venv.
#  - Still AUTO-RUN, only asks once for Chrome .deb choice, no Firefox steps.

set -euo pipefail

# ====== Helpers ======
log()   { echo -e "$1"; }
need_sudo() { if ! sudo -v; then echo "Cần quyền sudo để tiếp tục."; exit 1; fi }
is_cmd() { command -v "$1" &>/dev/null; }

# ====== Robust installer for gdown ======
ensure_gdown() {
  # Try to guarantee python venv support
  need_sudo
  sudo apt update -y || true
  sudo apt install -y python3-venv python3-pip || true

  export PATH="$HOME/.local/bin:$PATH"

  local VENV="$HOME/gdown-venv"
  # If a broken/incomplete venv folder exists, remove it
  if [[ -d "$VENV" && ! -f "$VENV/bin/activate" ]]; then
    rm -rf "$VENV"
  fi

  # Try to (re)create venv if needed
  if [[ ! -f "$VENV/bin/activate" ]]; then
    python3 -m venv "$VENV" || true
  fi

  if [[ -f "$VENV/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source "$VENV/bin/activate"
    python -m pip install --no-cache-dir --upgrade pip gdown
    return 0
  fi

  # ---- Fallback: user install (no venv) ----
  echo "⚠️ Không tạo được venv — chuyển sang cài gdown ở user site..."
  python3 -m pip install --user --no-cache-dir --upgrade pip gdown
  if ! is_cmd gdown; then
    # Some shells need PATH updated for this session
    export PATH="$HOME/.local/bin:$PATH"
  fi
  if ! is_cmd gdown; then
    echo "❌ Không thể cài gdown. Kiểm tra lại python/pip và mạng rồi chạy lại."; exit 1
  fi
}

# ====== 1) Cập nhật & gói nền ======
base_setup() {
  need_sudo
  log "🔄 Đang cập nhật hệ thống & thêm universe..."
  sudo add-apt-repository universe -y || true
  sudo apt update && sudo apt upgrade -y

  log "📦 Cài Open VM Tools..."
  sudo apt install -y open-vm-tools open-vm-tools-desktop || echo "⚠️ Không có gói Open VM Tools phù hợp."

  log "📦 Cài unzip, build-essential & Qt5 libs (cho Nekobox)..."
  sudo apt install -y unzip build-essential \
    libqt5network5 libqt5core5a libqt5gui5 libqt5widgets5 \
    qtbase5-dev libqt5x11extras5 libqt5quick5 libqt5quickwidgets5 libqt5quickparticles5

  log "✅ Hoàn tất bước nền."
}

# ====== 2) Cài Chrome từ Google Drive & tắt update ======
install_chrome_from_drive() {
  ensure_gdown

  local CHROME_DRIVE_ID="${CHROME_DRIVE_ID:-1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1}"
  local DOWNLOAD_DIR="$HOME/browser_temp"
  mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

  log "📥 Tải thư mục Chrome từ Google Drive..."
  gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies

  log "🔍 Liệt kê các gói Chrome (.deb) đã tải:"
  mapfile -t FILES < <(find "$DOWNLOAD_DIR" -type f -name "*.deb" | sort)
  if (( ${#FILES[@]} == 0 )); then
    echo "❌ Không tìm thấy file .deb nào trong thư mục tải về!"; exit 1
  fi
  nl -w2 -s". " <(printf "%s\n" "${FILES[@]}")
  read -rp "👉 Nhập số thứ tự file Chrome muốn cài: " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#FILES[@]} )); then
    echo "❌ Lựa chọn không hợp lệ!"; exit 1
  fi
  local FILE_SELECT="${FILES[$((choice-1))]}"
  echo "✅ Chọn file: $FILE_SELECT"

  log "🧹 Dọn dẹp file không dùng..."
  find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$FILE_SELECT")" -delete || true

  need_sudo
  log "🗑️ Gỡ Chrome bản đang có (nếu có)..."
  sudo apt remove -y google-chrome-stable || true

  log "🚀 Cài Chrome từ gói đã chọn..."
  sudo dpkg -i "$FILE_SELECT" || sudo apt -f install -y
  sudo apt-mark hold google-chrome-stable || true
  sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null || true

  log "🚫 Tắt update nội bộ Chrome..."
  sudo rm -rf /opt/google/chrome/cron/ || true
  sudo mkdir -p /etc/opt/chrome/policies/managed
  cat <<'JSON' >/tmp/disable_update.json
{
  "AutoUpdateCheckPeriodMinutes": 0,
  "DisableAutoUpdateChecksCheckbox": true,
  "MetricsReportingEnabled": false
}
JSON
  sudo mv /tmp/disable_update.json /etc/opt/chrome/policies/managed/disable_update.json
  sudo chmod -R 000 /opt/google/chrome/cron || true

  log "🎨 Tạo shortcut Chrome (Custom)..."
  cat <<'EOF' > ~/.local/share/applications/browser_custom.desktop
[Desktop Entry]
Name=Google Chrome (Custom)
Exec=/usr/bin/google-chrome-stable %U
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF

  if is_cmd gsettings; then
    gio set ~/.local/share/applications/browser_custom.desktop metadata::trusted true 2>/dev/null || true
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'browser_custom.desktop']/")"
  else
    echo "ℹ️ Lubuntu (LXQt): hãy nhấp phải biểu tượng trong menu -> 'Pin to Panel'."
  fi

  log "✅ Hoàn tất cài Chrome (đã khóa & tắt update nội bộ)."
}

# ====== 3) Sửa vấn đề password + auto-login ======
fix_passwords() {
  need_sudo
  log "🔧 Đang sửa tất cả vấn đề password..."

  log "🔓 Xóa password user..."
  sudo passwd -d "$USER" || true

  log "⚡ Cấu hình sudo không cần password..."
  echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER" >/dev/null

  log "🚀 Cấu hình auto-login cho LightDM (Lubuntu)..."
  sudo mkdir -p /etc/lightdm/lightdm.conf.d
  sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf >/dev/null <<EOF
[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
autologin-session=Lubuntu
EOF

  log "🚀 Cấu hình auto-login cho GDM3 (Ubuntu)..."
  sudo tee /etc/gdm3/custom.conf >/dev/null <<EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$USER
EOF

  log "🔑 Gỡ GNOME Keyring & KDE Wallet (nếu có)..."
  sudo apt remove --purge -y gnome-keyring seahorse 2>/dev/null || true
  sudo apt remove --purge -y kwalletmanager kwallet-kf5 2>/dev/null || true

  log "🗑️ Xóa dữ liệu keyring..."
  rm -rf ~/.local/share/keyrings ~/.gnupg ~/.config/kwalletrc 2>/dev/null || true

  log "🔒 Vô hiệu PAM keyring..."
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/login 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/passwd 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-password 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-autologin 2>/dev/null || true

  log "🛡️ Tắt PolicyKit password prompts..."
  sudo mkdir -p /etc/polkit-1/localauthority/50-local.d
  sudo tee /etc/polkit-1/localauthority/50-local.d/disable-passwords.pkla >/dev/null <<EOF
[Disable password prompts for $USER]
Identity=unix-user:$USER
Action=*
ResultActive=yes
ResultInactive=yes
ResultAny=yes
EOF

  log "🌐 Cấu hình Chrome không hỏi password..."
  mkdir -p ~/.config/google-chrome/Default
  cat > ~/.config/google-chrome/Default/Preferences <<'EOF'
{
   "profile": {
      "password_manager_enabled": false,
      "default_content_setting_values": {
         "password_manager": 2
      }
   }
}
EOF

  log "⚙️ Tạo .desktop cho Chrome dùng --password-store=basic..."
  sudo rm -f /usr/share/applications/google-chrome.desktop 2>/dev/null || true
  cat > ~/.local/share/applications/google-chrome.desktop <<'EOF'
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

  log "✅ ĐÃ SỬA XONG."
}

# ====== 4) Cài Nekobox ======
install_nekobox() {
  ensure_gdown
  log "📂 Chuẩn bị thư mục Nekobox..."
  rm -rf "$HOME/Downloads/nekoray"
  mkdir -p "$HOME/Downloads/nekoray"

  log "⬇️ Tải Nekobox từ Google Drive..."
  cd "$HOME/Downloads"
  local FILE_ID="${NEKOBOX_FILE_ID:-1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj}"
  gdown --id "$FILE_ID" -O nekobox.zip || { echo "❌ Tải thất bại! Kiểm tra FILE_ID."; return 1; }

  log "📂 Giải nén..."
  unzip -o nekobox.zip -d "$HOME/Downloads/nekoray"

  local inner_dir
  inner_dir=$(find "$HOME/Downloads/nekoray" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)
  if [[ -n "${inner_dir:-}" && "$inner_dir" != "$HOME/Downloads/nekoray" ]]; then
    log "📂 Điều chỉnh cấu trúc thư mục..."
    mv "$inner_dir"/* "$HOME/Downloads/nekoray/" || true
    rm -rf "$inner_dir"
  fi

  log "🔑 Cấp quyền thực thi..."
  cd "$HOME/Downloads/nekoray"
  chmod +x launcher nekobox nekobox_core 2>/dev/null || echo "⚠️ Một số file không tồn tại, bỏ qua."

  log "🖥️ Tạo shortcut Desktop & autostart..."
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

  mkdir -p "$HOME/.config/autostart"
  cp "$HOME/Desktop/nekoray.desktop" "$HOME/.config/autostart/nekoray.desktop"
  chmod +x "$HOME/.config/autostart/nekoray.desktop"

  if [[ "${XDG_CURRENT_DESKTOP:-}" =~ GNOME ]]; then
    log "📌 GNOME: pin Nekobox vào favorites..."
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'nekoray.desktop']/")" || true
  elif [[ "${XDG_CURRENT_DESKTOP:-}" =~ LXQt ]]; then
    log "📌 LXQt không hỗ trợ auto pin — bạn có thể kéo shortcut vào panel."
  else
    log "ℹ️ Môi trường desktop không xác định: ${XDG_CURRENT_DESKTOP:-unknown}."
  fi

  log "🚀 Thử chạy Nekobox..."
  ./nekobox || echo "⚠️ Không tự chạy được — mở bằng $HOME/Downloads/nekoray/nekobox."

  log "✅ Hoàn tất cài Nekobox."
}

# ====== AUTO RUN ======
main() {
  log "===== AIO Setup 24.04 (Auto-run v2) ====="
  base_setup
  install_chrome_from_drive
  fix_passwords
  install_nekobox
  log "🎉 Tất cả bước đã chạy xong. Khuyến nghị tự reboot máy để áp dụng hoàn toàn."
}
main
