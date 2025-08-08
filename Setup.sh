#!/bin/bash
# All-in-one setup for Ubuntu/Lubuntu 24.04 (AUTO-RUN)
# Source features merged and adapted from: ChromeOld.sh, fix_password_issues.sh, SetupVm.bash
# Behavior per user request:
#  - Auto run all steps sequentially without a menu.
#  - Only prompt ONCE: to choose which Chrome .deb file to install from the downloaded Google Drive folder.
#  - Remove Firefox install/uninstall features. (No Firefox modifications are performed.)

set -euo pipefail

# ====== Helpers ======
log()   { echo -e "$1"; }
need_sudo() { if ! sudo -v; then echo "Cần quyền sudo để tiếp tục."; exit 1; fi }
is_cmd() { command -v "$1" &>/dev/null; }

# ====== Global venv for gdown (reuse across steps) ======
ensure_gdown() {
  if [[ ! -d "$HOME/gdown-venv" ]]; then
    log "📦 Tạo venv Python cho gdown..."
    python3 -m venv "$HOME/gdown-venv"
  fi
  # shellcheck disable=SC1091
  source "$HOME/gdown-venv/bin/activate"
  pip install --no-cache-dir --upgrade pip gdown
}

# ====== 1) Cập nhật & gói nền (từ SetupVm.bash) ======
base_setup() {
  need_sudo
  log "🔄 Đang cập nhật hệ thống & thêm universe..."
  sudo add-apt-repository universe -y || true
  sudo apt update && sudo apt upgrade -y

  log "📦 Cài Open VM Tools..."
  sudo apt install -y open-vm-tools open-vm-tools-desktop || echo "⚠️ Không có gói Open VM Tools phù hợp."

  log "📦 Cài python3-pip, unzip, venv..."
  sudo apt install -y python3-pip unzip python3-venv

  log "📦 Cài build-essential & Qt5 libs (cho Nekobox)..."
  sudo apt install -y build-essential \
    libqt5network5 libqt5core5a libqt5gui5 libqt5widgets5 \
    qtbase5-dev libqt5x11extras5 libqt5quick5 libqt5quickwidgets5 libqt5quickparticles5

  log "✅ Hoàn tất bước nền."
}

# ====== 2) Cài Chrome từ Google Drive & tắt update ======
install_chrome_from_drive() {
  need_sudo
  ensure_gdown

  # 👉 Thay ID này nếu cần. Có thể override bằng biến môi trường trước khi chạy: CHROME_DRIVE_ID=... ./script.sh
  local CHROME_DRIVE_ID="${CHROME_DRIVE_ID:-1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1}"
  local DOWNLOAD_DIR="$HOME/browser_temp"
  mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

  log "📥 Tải thư mục Chrome từ Google Drive..."
  gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies

  # Chỉ hỏi người dùng MỘT LẦN để chọn file .deb
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

  log "🗑️ Gỡ Chrome bản đang có (nếu có)..."
  sudo apt remove -y google-chrome-stable || true

  log "🚀 Cài Chrome từ gói đã chọn..."
  sudo dpkg -i "$FILE_SELECT" || sudo apt -f install -y
  sudo apt-mark hold google-chrome-stable || true
  sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null || true

  # Tắt update nội bộ Chrome
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

  # Tạo shortcut riêng và pin
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

# ====== 3) Sửa vấn đề password + auto-login (Firefox-related steps removed) ======
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

[security]

[xdmcp]

[chooser]

[debug]
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

  log "⚙️ Tắt gnome-keyring-daemon (user)..."
  systemctl --user disable gnome-keyring-daemon 2>/dev/null || true
  systemctl --user stop gnome-keyring-daemon 2>/dev/null || true

  log "🔧 Tạo .desktop cho Chrome dùng --password-store=basic..."
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

  log "✅ ĐÃ SỬA XONG. (Không hỏi thêm gì khác.)"
}

# ====== 4) Cài Nekobox (từ SetupVm.bash) ======
install_nekobox() {
  ensure_gdown
  log "📂 Chuẩn bị thư mục Nekobox..."
  rm -rf "$HOME/Downloads/nekoray"
  mkdir -p "$HOME/Downloads/nekoray"

  log "⬇️ Tải Nekobox từ Google Drive..."
  cd "$HOME/Downloads"
  local FILE_ID="${NEKOBOX_FILE_ID:-1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj}"   # Cho phép override qua biến môi trường
  gdown --id "$FILE_ID" -O nekobox.zip || { echo "❌ Tải thất bại! Kiểm tra FILE_ID."; return 1; }

  log "📂 Giải nén..."
  unzip -o nekobox.zip -d "$HOME/Downloads/nekoray"

  # Sửa cấu trúc thư mục lồng nhau nếu có
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

  # Pin vào taskbar nếu GNOME
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

  # Post-checks
  log ""
  log "🔍 Kiểm tra sau cài:"
  for pkg in open-vm-tools open-vm-tools-desktop python3-pip unzip build-essential qtbase5-dev; do
    if dpkg -l | grep -q "^ii\s*$pkg"; then echo "✅ $pkg installed"; else echo "❌ $pkg missing"; fi
  done
  echo "🐍 $(python3 --version)"; echo "$(pip3 --version || true)"
  if python3 -m pip show gdown >/dev/null 2>&1; then echo "✅ gdown installed"; else echo "❌ gdown missing"; fi
  [[ -d "$HOME/Downloads/nekoray" ]] && echo "✅ Thư mục Nekoray OK" || echo "❌ Thiếu thư mục Nekoray"
  [[ -f "$HOME/Desktop/nekoray.desktop" ]] && echo "✅ Shortcut Desktop OK" || echo "❌ Thiếu shortcut Desktop"

  log "✅ Hoàn tất cài Nekobox."
}

# ====== AUTO RUN ======
main() {
  log "===== AIO Setup 24.04 (Auto-run) ====="
  base_setup
  install_chrome_from_drive   # 💬 Chỉ nhắc chọn file Chrome .deb ở đây
  fix_passwords
  install_nekobox
  log "🎉 Tất cả bước đã chạy xong. Khuyến nghị tự reboot máy để áp dụng hoàn toàn."
}
main
