
#!/bin/bash

# === Cài đặt Python venv và gdown ===
if [[ ! -d "$HOME/gdown-venv" ]]; then
    echo "📦 Đang tạo venv Python và cài gdown..."
    python3 -m venv ~/gdown-venv
fi

source ~/gdown-venv/bin/activate

# Cài gdown trong venv (đảm bảo luôn có)
pip install --no-cache-dir gdown

# === Cấu hình Google Drive Folder ID ===
CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
DOWNLOAD_DIR="$HOME/browser_temp"
mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

# === Chọn trình duyệt muốn cài ===
echo "Chọn trình duyệt muốn cài: Chrome"
DRIVE_ID="$CHROME_DRIVE_ID"
BTYPE="chrome"

# === Tải toàn bộ folder từ Google Drive ===
echo "📥 Đang tải toàn bộ folder $BTYPE từ Google Drive..."
gdown --folder "https://drive.google.com/drive/folders/$DRIVE_ID" --no-cookies

# === Liệt kê file tải về ===
echo "🔍 Danh sách file tải về:"
FILE_LIST=$(find "$DOWNLOAD_DIR" -type f -name "*.deb")

if [[ -z "$FILE_LIST" ]]; then
    echo "❌ Không tìm thấy file hợp lệ!"
    exit 1
fi

# Hiển thị danh sách để chọn
echo "$FILE_LIST" | nl -s". "
read -p "👉 Nhập số thứ tự file muốn cài: " choice

FILE_SELECT=$(echo "$FILE_LIST" | sed -n "${choice}p")

if [[ ! -f "$FILE_SELECT" ]]; then
    echo "❌ File không tồn tại!"
    exit 1
fi

echo "✅ Chọn file: $FILE_SELECT"

# === Xóa file không được chọn để tiết kiệm dung lượng ===
echo "🧹 Dọn dẹp file không dùng..."
find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$FILE_SELECT")" -delete

# === Gỡ bản mặc định của Chrome ===
echo "🗑️ Gỡ bản mặc định của Chrome..."
sudo apt remove -y google-chrome-stable || true

# === Cài đặt và khóa cập nhật Chrome ===
echo "🚀 Đang cài Chrome..."
sudo dpkg -i "$FILE_SELECT"
sudo apt -f install -y
sudo apt-mark hold google-chrome-stable
sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null

# 🔒 Tắt update nội bộ của Chrome
echo "🚫 Tắt update nội bộ Chrome..."
sudo rm -rf /opt/google/chrome/cron/
sudo mkdir -p /etc/opt/chrome/policies/managed
cat <<EOF > /tmp/disable_update.json
{
  "AutoUpdateCheckPeriodMinutes": 0,
  "DisableAutoUpdateChecksCheckbox": true,
  "MetricsReportingEnabled": false
}
EOF
sudo mv /tmp/disable_update.json /etc/opt/chrome/policies/managed/disable_update.json
sudo chmod -R 000 /opt/google/chrome/cron || true

# === Tạo shortcut cho Chrome ===
echo "🎨 Tạo shortcut cho Chrome..."
cat <<EOF3 > ~/.local/share/applications/browser_custom.desktop
[Desktop Entry]
Name=Google Chrome (Custom)
Exec=/usr/bin/google-chrome-stable %U
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF3

# === Pin vào taskbar ===
if command -v gsettings &>/dev/null; then
    gio set ~/.local/share/applications/browser_custom.desktop metadata::trusted true 2>/dev/null
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'browser_custom.desktop']/")"
else
    echo "ℹ️ Trên Lubuntu (LXQt), hãy nhấp phải biểu tượng trong menu -> 'Pin to Panel'."
fi

echo "✅ Chrome đã được cài, khóa update và tắt update nội bộ."

# === SỬA TẤT CẢ VẤN ĐỀ PASSWORD ===

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

# === Hoàn tất cài đặt ===
echo "✅ Hoàn tất setup!"

# === Phần Nekobox ===

# 5. Prepare Nekobox folder
echo "📂 Preparing Nekobox folder..."
rm -rf ~/Downloads/nekoray
mkdir -p ~/Downloads/nekoray

# 6. Download Nekobox ZIP from Google Drive
echo "⬇️ Downloading Nekobox from Google Drive..."
cd ~/Downloads

# ⚠️ Thay ID này bằng ID thực tế của file Nekobox trên Google Drive!
FILE_ID="1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj"  
gdown --id "$FILE_ID" -O nekobox.zip || { echo "❌ Download failed! Check Google Drive file ID."; exit 1; }

# 7. Extract Nekobox
echo "📂 Extracting Nekobox..."
unzip -o nekobox.zip -d ~/Downloads/nekoray

# 8. Handle nested folders
inner_dir=$(find ~/Downloads/nekoray -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ "$inner_dir" != "" ] && [ "$inner_dir" != "$HOME/Downloads/nekoray" ]; then
    echo "📂 Adjusting folder structure..."
    mv "$inner_dir"/* ~/Downloads/nekoray/
    rm -rf "$inner_dir"
fi

# 9. Grant execution permissions
echo "🔑 Setting execution permissions..."
cd ~/Downloads/nekoray
chmod +x launcher nekobox nekobox_core || echo "⚠️ Some files not found, skipping chmod."

# 10. Create desktop shortcut
echo "🖥️ Creating desktop shortcut..."
cat <<EOF > ~/Desktop/nekoray.desktop
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

chmod +x ~/Desktop/nekoray.desktop

echo "📌 Pinning Nekobox to taskbar and enabling autostart..."

# Pin cho Ubuntu GNOME
if echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
    echo "📌 Ubuntu GNOME detected - pinning Nekobox to taskbar..."
    gsettings set org.gnome.shell favorite-apps     "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'nekoray.desktop']/")" || true
elif echo "$XDG_CURRENT_DESKTOP" | grep -qi "LXQt"; then
    echo "📌 Lubuntu LXQt detected - LXQt không hỗ trợ auto pin, bạn có thể kéo shortcut vào panel thủ công."
else
    echo "ℹ️ Unknown desktop environment: $XDG_CURRENT_DESKTOP - skipping auto pinning."
fi

# Autostart cho cả Ubuntu & Lubuntu
mkdir -p ~/.config/autostart
cp ~/Desktop/nekoray.desktop ~/.config/autostart/nekoray.desktop
chmod +x ~/.config/autostart/nekoray.desktop

echo "✅ Nekobox pinned to taskbar (Ubuntu GNOME) and set to autostart."

# 11. Launch Nekobox
echo "🚀 Launching Nekobox..."
./nekobox || echo "⚠️ Unable to launch Nekobox automatically. Start manually from ~/Downloads/nekoray."

echo "✅ Setup completed successfully!"

