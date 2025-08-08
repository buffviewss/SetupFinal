#!/bin/bash
# All-in-one setup for Ubuntu/Lubuntu 24.04 (AUTO-RUN) — v15
# - Based on v14
# - Robust listing:
#   * Detect support with `gdown list --help`
#   * Try both folder URL and bare ID
#   * If listing yields nothing, prompt FILE_ID with correct reason

set -euo pipefail

log(){ echo -e "$1"; }
need_sudo(){ if ! sudo -v; then echo "Cần quyền sudo."; exit 1; fi }
is_cmd(){ command -v "$1" &>/dev/null; }
is_gnome(){ [[ "${XDG_CURRENT_DESKTOP:-}" =~ GNOME ]] && is_cmd gsettings && gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.shell$'; }
is_lxqt(){ [[ "${XDG_CURRENT_DESKTOP:-}" =~ LXQt|LXQT|LxQt ]] || pgrep -x lxqt-panel >/dev/null 2>&1; }

# ===== helpers =====
purge_if_installed(){
  need_sudo
  for pkg in "$@"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      sudo apt purge -y "$pkg" || true
    fi
  done
}

# ===== gdown installer (force >=5.2.0) =====
ensure_gdown(){
  need_sudo; sudo apt update -y || true; sudo apt install -y python3-venv python3-pip || true

  export PATH="$HOME/.local/bin:$PATH"
  local VENV="$HOME/gdown-venv"

  # If venv exists but `gdown list` not available, wipe and recreate
  if [[ -d "$VENV" && -f "$VENV/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source "$VENV/bin/activate"
    if ! (gdown list --help >/dev/null 2>&1); then
      deactivate || true
      rm -rf "$VENV"
    fi
  elif [[ -d "$VENV" && ! -f "$VENV/bin/activate" ]]; then
    rm -rf "$VENV"
  fi

  [[ ! -f "$VENV/bin/activate" ]] && python3 -m venv "$VENV" || true
  if [[ -f "$VENV/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source "$VENV/bin/activate"
    python -m pip install --no-cache-dir --upgrade pip
    python -m pip install --no-cache-dir --upgrade "gdown>=5.2.0"
    return 0
  fi

  # Fallback to user install (still force >=5.2.0)
  python3 -m pip install --user --no-cache-dir --upgrade pip || true
  python3 -m pip install --user --no-cache-dir --upgrade "gdown>=5.2.0"
  export PATH="$HOME/.local/bin:$PATH"
  is_cmd gdown || { echo "❌ Không thể cài gdown."; exit 1; }
}

# ===== LXQt Quicklaunch helpers =====
ensure_lxqt_quicklaunch_plugin(){
  local conf="$HOME/.config/lxqt/panel.conf"
  mkdir -p "$HOME/.config/lxqt"
  touch "$conf"
  if [[ -z "${_LXQT_BACKUP_DONE:-}" ]]; then
    cp -f "$conf" "$conf.bak.$(date +%s)" 2>/dev/null || true
    _LXQT_BACKUP_DONE=1
  fi
  if grep -q '^plugins=' "$conf"; then
    if ! grep -E '^plugins=.*\bquicklaunch\b' "$conf" >/dev/null; then
      sed -i 's/^plugins=\(.*\)$/plugins=quicklaunch,\1/' "$conf"
    fi
  else
    awk '
      BEGIN{done=0}
      /^\[panel/ && done==0 { print; print "plugins=quicklaunch"; done=1; next }
      { print }
      END{ if(done==0) { print "\n[panel]\nplugins=quicklaunch" } }
    ' "$conf" > "$conf.tmp" && mv "$conf.tmp" "$conf"
  fi
}

pin_lxqt_quicklaunch(){
  local desktop="$1"
  local conf="$HOME/.config/lxqt/panel.conf"
  ensure_lxqt_quicklaunch_plugin
  if ! grep -q '^\[quicklaunch\]' "$conf"; then
    printf "\n[quicklaunch]\napps\\size=0\n" >> "$conf"
  fi
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
        if ($0 ~ /^apps\\size=/) { split($0,a,"="); cnt = a[2]+0; next }
      }
      print
    }
    END{ if (insec) { flush_section() } }
  ' "$conf" > "$conf.tmp" && mv "$conf.tmp" "$conf"
  if is_cmd lxqt-panel; then
    pkill -x lxqt-panel >/dev/null 2>&1 || true
    (nohup lxqt-panel >/dev/null 2>&1 &)
  fi
}

# ===== Extra hard lock for Chrome via APT pin =====
lock_chrome_with_apt_pin(){
  need_sudo
  sudo mkdir -p /etc/apt/preferences.d
  sudo tee /etc/apt/preferences.d/99-hold-google-chrome.pref >/dev/null <<'EOF'
Package: google-chrome-stable
Pin: release *
Pin-Priority: -1
EOF
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

# --- FORCE choose .deb name/ID first (no folder download) ---
choose_chrome_file_from_drive(){
  local CHROME_DRIVE_ID="$1"
  local FOLDER_URL="https://drive.google.com/drive/folders/$CHROME_DRIVE_ID"
  local raw=""

  if (gdown list --help >/dev/null 2>&1); then
    log "📋 Lấy danh sách file trong thư mục Drive (không tải xuống)..."
    raw="$(gdown list "$FOLDER_URL" --no-cookies 2>/dev/null || true)"
    if [[ -z "$raw" ]]; then
      # try bare ID form as well
      raw="$(gdown list "$CHROME_DRIVE_ID" --no-cookies 2>/dev/null || true)"
    fi
  fi

  if [[ -z "$raw" ]]; then
    echo "⚠️ Không liệt kê được thư mục (có thể ID sai hoặc thư mục cần đăng nhập)."
    echo "👉 Dán FILE_ID của gói .deb bạn muốn cài (bắt buộc, sẽ không tải cả thư mục):"
    read -rp "FILE_ID: " MANUAL_ID
    if [[ -z "${MANUAL_ID:-}" ]]; then
      echo "❌ Không có FILE_ID và không thể liệt kê thư mục. Thoát."
      exit 1
    fi
    CHOSEN_ID="$MANUAL_ID"
    CHOSEN_NAME="chrome_selected.deb"
    return 0
  fi

  mapfile -t rows < <(echo "$raw" | awk '/\.deb([[:space:]]|$)/ {print}')
  if (( ${#rows[@]} == 0 )); then
    echo "❌ Không tìm thấy file .deb trong thư mục."; exit 1
  fi

  echo "Các bản Chrome có sẵn:"
  declare -a IDS NAMES
  local idx=1
  for line in "${rows[@]}"; do
    local id name
    id="$(echo "$line" | awk '{print $1}')"
    name="$(echo "$line" | sed -E 's/^[^ ]+ //; s/ [0-9.]+([KMG]i?B)?$//')"
    IDS[$idx]="$id"; NAMES[$idx]="$name"
    printf "  %2d) %s\n" "$idx" "$name"
    idx=$((idx+1))
  done
  read -rp "👉 Chọn số thứ tự gói cần tải & cài: " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice<1 || choice>=idx )); then
    echo "❌ Lựa chọn không hợp lệ."; exit 1
  fi
  CHOSEN_ID="${IDS[$choice]}"
  CHOSEN_NAME="${NAMES[$choice]}"
  return 0
}

# ===== 2) Chrome =====
install_chrome_from_drive(){
  ensure_gdown
  local CHROME_DRIVE_ID="${CHROME_DRIVE_ID:-1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1}"
  local DOWNLOAD_DIR="$HOME/browser_temp"
  mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

  choose_chrome_file_from_drive "$CHROME_DRIVE_ID"
  log "📥 Tải duy nhất file đã chọn: $CHOSEN_NAME"
  gdown --id "$CHOSEN_ID" -O "$CHOSEN_NAME"
  local FILE_SELECT="$DOWNLOAD_DIR/$CHOSEN_NAME"
  [[ -f "$FILE_SELECT" ]] || { echo "❌ Tải file thất bại."; exit 1; }

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
    sudo chmod -R 000 /opt/google/chrome/cron 2>/dev/null || true
    sudo rm -rf /opt/google/chrome/cron/ 2>/dev/null || true
  fi
  sudo mkdir -p /etc/opt/chrome/policies/managed
  cat <<'JSON' >/tmp/disable_update.json
{
  "AutoUpdateCheckPeriodMinutes": 0,
  "DisableAutoUpdateChecksCheckbox": true
}
JSON
  sudo mv /tmp/disable_update.json /etc/opt/chrome/policies/managed/disable_update.json

  log "🎯 Áp dụng APT pin (hard lock) cho Chrome..."
  lock_chrome_with_apt_pin

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

  if [[ -d /etc/gdm3 ]]; then
    sudo tee /etc/gdm3/custom.conf >/dev/null <<EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$USER
EOF
  fi

  purge_if_installed gnome-keyring seahorse kwalletmanager kwallet-kf5

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
  log "===== AIO Setup 24.04 (Auto-run v15, robust list) ====="
  base_setup
  install_chrome_from_drive
  fix_passwords
  install_nekobox

  need_sudo
  sudo apt autoremove -y || true
  sudo apt clean || true
  log "🧹 Đã dọn gói thừa (autoremove + clean)."
  log "🎉 Hoàn tất. Khuyến nghị reboot."
}
main
