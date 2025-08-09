#!/bin/bash

# ============================
# Cài đặt Python venv và gdown
# ============================

if [[ ! -d "$HOME/gdown-venv" ]]; then
    echo "📦 Đang tạo venv Python và cài gdown..."
    python3 -m venv ~/gdown-venv
fi

source ~/gdown-venv/bin/activate
pip install --no-cache-dir gdown

# ============================
# Cấu hình Google Drive Folder ID
# ============================

CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
DOWNLOAD_DIR="$HOME/browser_temp"
mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

# ============================
# Chọn trình duyệt Chrome
# ============================

echo "Chọn trình duyệt muốn cài:"
select browser in "Chrome" "Thoát"; do
    case $browser in
        Chrome) DRIVE_ID="$CHROME_DRIVE_ID"; BTYPE="chrome"; break;;
        Thoát) echo "🚪 Thoát script."; exit 0;;
        *) echo "❌ Lựa chọn không hợp lệ!";;
    esac
done

# ============================
# Tải toàn bộ folder từ Google Drive
# ============================

echo "📥 Đang tải toàn bộ folder $BTYPE từ Google Drive..."
gdown --folder "https://drive.google.com/drive/folders/$DRIVE_ID" --no-cookies

# ============================
# Liệt kê và chọn file tải về
# ============================

echo "🔍 Danh sách file tải về:"
FILE_LIST=$(find "$DOWNLOAD_DIR" -type f)
if [[ -z "$FILE_LIST" ]]; then
    echo "❌ Không tìm thấy file hợp lệ!"
    exit 1
fi

echo "$FILE_LIST" | nl -s". "
read -p "👉 Nhập số thứ tự file muốn cài: " choice
FILE_SELECT=$(echo "$FILE_LIST" | sed -n "${choice}p")

if [[ ! -f "$FILE_SELECT" ]]; then
    echo "❌ File không tồn tại!"
    exit 1
fi

echo "✅ Chọn file: $FILE_SELECT"

# ============================
# === Cài đặt và khóa cập nhật ===
if [[ $BTYPE == "chrome" ]]; then
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
    
    # Tắt repo Google Chrome để ngừng cập nhật từ nguồn chính thức
    sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null

# ============================
# Cài đặt Open VM Tools cho VMware
# ============================

echo "📦 Installing Open VM Tools and required libraries for VMware..."
sudo apt install -y open-vm-tools open-vm-tools-desktop python3-pip unzip
sudo apt install -y build-essential \
libqt5network5 \
libqt5core5a \
libqt5gui5 \
libqt5widgets5 \
qtbase5-dev \
libqt5x11extras5 \
libqt5quick5 \
libqt5quickwidgets5 \
libqt5quickparticles5 || echo "⚠️ Some VMware dependencies could not be installed."

# ============================
# Cấu hình không yêu cầu password
# ============================

echo "🔧 Đang sửa tất cả vấn đề password..."

# Xóa password user hiện tại
echo "🔓 Xóa password user..."
sudo passwd -d $USER

# Cấu hình sudo không cần password
echo "⚡ Cấu hình sudo không cần password..."
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER

# Cấu hình auto-login cho LightDM (Lubuntu)
echo "🚀 Cấu hình auto-login cho LightDM..."
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf << EOF
[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
autologin-session=Lubuntu
EOF

# Cấu hình auto-login cho GDM3 (Ubuntu)
echo "🚀 Cấu hình auto-login cho GDM3..."
sudo tee /etc/gdm3/custom.conf << EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$USER
EOF

# ============================
# Tắt GNOME Keyring và Chrome Keyring
# ============================

echo "🔑 Tắt GNOME Keyring..."
sudo apt remove --purge -y gnome-keyring seahorse || true

echo "🔒 Tắt PAM keyring..."
sudo sed -i 's/.*pam_gnome_keyring.so.*/#&/' /etc/pam.d/login 2>/dev/null || true

# ============================
# Cấu hình Chrome không yêu cầu password
# ============================

echo "🌐 Cấu hình Chrome không yêu cầu password..."
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

# ============================
# Cài đặt Nekobox
# ============================

echo "📦 Installing Nekobox dependencies and setup..."
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install --upgrade pip gdown

echo "📂 Downloading and extracting Nekobox..."
gdown --id "1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj" -O nekobox.zip
unzip -o nekobox.zip -d ~/Downloads/nekoray

echo "🎨 Creating Nekobox shortcut..."
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

echo "✅ Nekobox setup completed!"

# ============================
# Khởi động lại hệ thống
# ============================

echo "🔄 Bắt buộc phải khởi động lại để áp dụng các thay đổi."
read -p "🔄 Khởi động lại ngay bây giờ? (y/n): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
fi
