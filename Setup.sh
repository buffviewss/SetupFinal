#!/bin/bash
# All-in-one setup for Ubuntu/Lubuntu 24.04 (AUTO-RUN) — v7
# Fixes:
#  - Lubuntu: skip GDM3 file if directory doesn't exist
#  - LXQt pin: fix awk syntax (no reserved 'in'), safer section handling

set -euo pipefail

log(){ echo -e "$1"; }
need_sudo(){ if ! sudo -v; then echo "Cần quyền sudo."; exit 1; fi }
is_cmd(){ command -v "$1" &>/dev/null; }
is_gnome(){ [[ "${XDG_CURRENT_DESKTOP:-}" =~ GNOME ]] && is_cmd gsettings && gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.shell$'; }
is_lxqt(){ [[ "${XDG_CURRENT_DESKTOP:-}" =~ LXQt|LXQT|LxQt ]] || pgrep -x lxqt-panel >/dev/null 2>&1; }

# ===== gdown installer =====
ensure_gdown(){
  need_sudo; sudo apt update -y || true; sudo apt install -y python3-venv python3-pip || true
  export PATH="$HOME/.local/bin:$PATH"
  local VENV="$HOME/gdown-venv"
  [[ -d "$VENV" && ! -f "$VENV/bin/activate" ]] && rm -rf "$VENV"
  [[ ! -f "$VENV/bin/activate" ]] && python3 -m venv "$VENV" || true
  if [[ -f "$VENV/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source "$VENV/bin/activate"
    python -m pip install --no-cache-dir --upgrade pip
    python -m pip install --no-cache-dir --upgrade gdown
    return 0
  fi
  python3 -m pip install --user --no-cache-dir --upgrade pip || true
  python3 -m pip install --user --no-cache-dir --upgrade gdown
  export PATH="$HOME/.local/bin:$PATH"
  is_cmd gdown || { echo "❌ Không thể cài gdown."; exit 1; }
}

# ===== LXQt Quicklaunch auto-pin (safer) =====
pin_lxqt_quicklaunch(){
  local desktop="$1"   # Full path to .desktop file
  local conf="$HOME/.config/lxqt/panel.conf"
  mkdir -p "$HOME/.config/lxqt"
  touch "$conf"

  # Backup once per run
  if [[ -z "${_LXQT_BACKUP_DONE:-}" ]]; then
    cp -f "$conf" "$conf.bak.$(date +%s)" 2>/dev/null || true
    _LXQT_BACKUP_DONE=1
  fi

  # Ensure [quicklaunch] section exists
  if ! grep -q '^\[quicklaunch\]' "$conf"; then
    printf "\n[quicklaunch]\napps\\size=0\n" >> "$conf"
  fi

  # Insert desktop entry into [quicklaunch] if not already present; recompute size
  awk -v d="$desktop" '
    BEGIN{insec=0; dup=0; cnt=-1}
    function flush_section(){
      if (insec) {
        if (dup==0) {
          if (cnt<0) cnt=0;
          print "apps\\" cnt "\\desktop=" d;
          cnt++;
        }
        print "apps\\size=" cnt;
        insec=0;
      }
    }
    /^\[quicklaunch\]$/ { print; insec=1; cnt=-1; next }
    /^\[/ {
      if (insec) { flush_section() }
      print; next
    }
    {
      if (insec) {
        if ($0 ~ /^apps\\[0-9]+\\desktop=/) {
          if (index($0, d) > 0) dup=1;
          print; next
        }
        if ($0 ~ /^apps\\size=/) {
          # capture size then skip (will rewrite)
          split($0,a,"="); cnt = a[2]+0; next
        }
      }
      print
    }
    END{ if (insec) { flush_section() } }
  ' "$conf" > "$conf.tmp" && mv "$conf.tmp" "$conf"

  # Restart LXQt panel to apply (best-effort)
  if is_cmd lxqt-panel; then
    pkill -x lxqt-panel >/dev/null 2>&1 || true
    (nohup lxqt-panel >/dev/null 2>&1 &)
  fi
}

# ===== 1) Base =====
base_setup(){
  need_sudo
  log "🔄 Cập nhật hệ thống..."
  sudo add-apt-repository universe -y || true
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y open-vm-tools open-vm-tools-desktop || echo "⚠️ Open VM Tools không khả dụng."
  sudo apt install -y unzip build-essential \
    libqt5network5 libqt5core5a libqt5gui5 libqt5widgets5 \
    qtbase5-dev libqt5x11extras5 libqt5quick5 libqt5quickwidgets5 libqt5quickparticles5
  log "✅ Hoàn tất bước nền."
}

# ===== 2) Chrome =====
install_chrome_from_drive(){
  ensure_gdown
  local CHROME_DRIVE_ID="${CHROME_DRIVE_ID:-1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1}"
  local DOWNLOAD_DIR="$HOME/browser_temp"
  mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"
  log "📥 Tải thư mục Chrome từ Google Drive..."
  gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies
  mapfile -t FILES < <(find "$DOWNLOAD_DIR" -type f -name "*.deb" | sort)
  (( ${#FILES[@]} )) || { echo "❌ Không tìm thấy file .deb."; exit 1; }
  nl -w2 -s". " <(printf "%s\n" "${FILES[@]}")
  read -rp "👉 Nhập số thứ tự file Chrome muốn cài: " choice
  [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#FILES[@]} )) || { echo "❌ Lựa chọn không hợp lệ!"; exit 1; }
  local FILE_SELECT="${FILES[$((choice-1))]}"
  echo "✅ Chọn file: $FILE_SELECT"
  find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$FILE_SELECT")" -delete || true

  need_sudo
  sudo apt remove -y google-chrome-stable || true
  if ! sudo dpkg -i "$FILE_SELECT"; then
    sudo apt -f install -y --allow-change-held-packages || true
    sudo dpkg -i "$FILE_SELECT" || true
  fi
  sudo apt-mark hold google-chrome-stable || true
  sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null || true

  log "🚫 Tắt update nội bộ Chrome..."
  if [[ -d /opt/google/chrome/cron ]]; then
    sudo rm -rf /opt/google/chrome/cron/ || true
    sudo chmod -R 000 /opt/google/chrome/cron || true
  fi
  sudo mkdir -p /etc/opt/chrome/policies/managed
  cat <<'JSON' >/tmp/disable_update.json
{
  "AutoUpdateCheckPeriodMinutes": 0,
  "DisableAutoUpdateChecksCheckbox": true,
  "MetricsReportingEnabled": false
}
JSON
  sudo mv /tmp/disable_update.json /etc/opt/chrome/policies/managed/disable_update.json

  log "🎨 Tạo shortcut Chrome (Custom)..."
  mkdir -p ~/.local/share/applications
  cat <<'EOF' > ~/.local/share/applications/browser_custom.desktop
[Desktop Entry]
Name=Google Chrome (Custom)
Exec=/usr/bin/google-chrome-stable %U
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF

  if is_gnome; then
    gio set ~/.local/share/applications/browser_custom.desktop metadata::trusted true 2>/dev/null || true
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'browser_custom.desktop']/")"
  fi
  if is_lxqt; then
    pin_lxqt_quicklaunch "$HOME/.local/share/applications/browser_custom.desktop"
  fi
  log "✅ Chrome đã cài & khóa update."
}

# ===== 3) Password & autologin =====
fix_passwords(){
  need_sudo
  log "🔧 Sửa vấn đề password & autologin..."
  sudo passwd -d "$USER" || true
  echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER" >/dev/null
  sudo mkdir -p /etc/lightdm/lightdm.conf.d
  sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf >/dev/null <<EOF
[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
autologin-session=Lubuntu
EOF

  # Only if gdm3 exists (Ubuntu GNOME), otherwise skip on Lubuntu
  if [[ -d /etc/gdm3 ]]; then
    sudo tee /etc/gdm3/custom.conf >/dev/null <<EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$USER
EOF
  else
    echo "ℹ️ GDM3 không tồn tại (Lubuntu dùng LightDM) — bỏ qua cấu hình GDM."
  fi

  sudo apt remove --purge -y gnome-keyring seahorse 2>/dev/null || true
  sudo apt remove --purge -y kwalletmanager kwallet-kf5 2>/dev/null || true
  rm -rf ~/.local/share/keyrings ~/.gnupg ~/.config/kwalletrc 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/login 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/passwd 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-password 2>/dev/null || true
  sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/gdm-autologin 2>/dev/null || true

  mkdir -p ~/.config/google-chrome/Default
  cat > ~/.config/google-chrome/Default/Preferences <<'EOF'
{
  "profile": { "password_manager_enabled": false,
    "default_content_setting_values": { "password_manager": 2 } }
}
EOF
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
  log "✅ Xong phần password & autologin."
}

# ===== 4) Nekobox =====
install_nekobox(){
  ensure_gdown
  log "📂 Chuẩn bị Nekobox..."
  rm -rf "$HOME/Downloads/nekoray"; mkdir -p "$HOME/Downloads/nekoray"
  cd "$HOME/Downloads"
  local FILE_ID="${NEKOBOX_FILE_ID:-1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj}"
  gdown --id "$FILE_ID" -O nekobox.zip || { echo "❌ Tải thất bại."; return 1; }
  unzip -o nekobox.zip -d "$HOME/Downloads/nekoray"
  local inner_dir; inner_dir=$(find "$HOME/Downloads/nekoray" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)
  if [[ -n "${inner_dir:-}" && "$inner_dir" != "$HOME/Downloads/nekoray" ]]; then
    mv "$inner_dir"/* "$HOME/Downloads/nekoray/" || true; rm -rf "$inner_dir"
  fi
  cd "$HOME/Downloads/nekoray"; chmod +x launcher nekobox nekobox_core 2>/dev/null || true

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
  mkdir -p "$HOME/.local/share/applications"
  cp "$HOME/Desktop/nekoray.desktop" "$HOME/.local/share/applications/nekoray.desktop"

  mkdir -p "$HOME/.config/autostart"; cp "$HOME/Desktop/nekoray.desktop" "$HOME/.config/autostart/nekoray.desktop"; chmod +x "$HOME/.config/autostart/nekoray.desktop"

  if is_gnome; then
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'nekoray.desktop']/")" || true
  fi
  if is_lxqt; then
    pin_lxqt_quicklaunch "$HOME/.local/share/applications/nekoray.desktop"
  fi
  ./nekobox || echo "ℹ️ Không tự chạy được — mở thủ công từ $HOME/Downloads/nekoray/nekobox."
  log "✅ Nekobox đã cài."
}

# ===== Auto-run =====
main(){
  log "===== AIO Setup 24.04 (Auto-run v7, Lubuntu fixes) ====="
  base_setup
  install_chrome_from_drive
  fix_passwords
  install_nekobox
  log "🎉 Hoàn tất. Khuyến nghị reboot."
}
main
