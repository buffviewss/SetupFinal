#!/bin/bash

# =========================
# Setup Ubuntu/Lubuntu (Combined Script)
# =========================

set -e  # Dừng nếu có lệnh thất bại

# 1. Cập nhật và nâng cấp hệ thống
echo "🔄 Cập nhật các gói hệ thống..."
sudo add-apt-repository universe -y || true
sudo apt update && sudo apt upgrade -y

# 2. Cài đặt Google Chrome (tương thích Ubuntu/Lubuntu 24.04)
echo "🌐 Cài đặt Google Chrome..."
if ! command -v google-chrome &> /dev/null; then
    echo "📦 Cài đặt Google Chrome từ Drive..."
    CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
    DOWNLOAD_DIR="$HOME/browser_temp"
    mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"
    
    # Tải Chrome từ Google Drive
    echo "📥 Đang tải Chrome..."
    gdown --folder "https://drive.google.com/drive/folders/$CHROME_DRIVE_ID" --no-cookies

    # Tìm và chọn file .deb để cài đặt
    FILE_LIST=$(find "$DOWNLOAD_DIR" -type f -name "*.deb")
    echo "$FILE_LIST" | nl -s". "
    read -p "👉 Nhập số thứ tự file muốn cài: " choice
    FILE_SELECT=$(echo "$FILE_LIST" | sed -n "${choice}p")

    if [[ ! -f "$FILE_SELECT" ]]; then
        echo "❌ Không tìm thấy file hợp lệ!"
        exit 1
    fi

    echo "✅ Chọn file: $FILE_SELECT"

    # Gỡ cài đặt bản Chrome mặc định nếu có
    echo "🗑️ Gỡ bản mặc định..."
    sudo apt remove -y google-chrome-stable || true

    # Cài đặt Chrome
    echo "🚀 Đang cài đặt Chrome..."
    sudo dpkg -i "$FILE_SELECT"
    sudo apt -f install -y
    sudo apt-mark hold google-chrome-stable
    sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null

    # Tắt cập nhật Chrome
    echo "🚫 Tắt cập nhật Chrome..."
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

    # Tạo shortcut
    echo "🎨 Tạo shortcut Google Chrome..."
    cat <<EOF3 > ~/.local/share/applications/browser_custom.desktop
[Desktop Entry]
Name=Google Chrome (Custom)
Exec=/usr/bin/google-chrome-stable %U
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF3

    # Pin vào taskbar nếu GNOME
    if command -v gsettings &>/dev/null; then
        if echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
            gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'browser_custom.desktop']/")"
        else
            echo "ℹ️ Môi trường desktop không phải GNOME, không thể pin vào taskbar."
        fi
    else
        echo "ℹ️ Không tìm thấy gsettings, không thể pin vào taskbar."
    fi

    echo "✅ Chrome đã được cài, khóa update và tắt update nội bộ."
else
    echo "✅ Google Chrome đã được cài đặt sẵn."
fi

# 3. Cài đặt các công cụ cần thiết
echo "📦 Cài đặt công cụ cần thiết..."
sudo apt install -y open-vm-tools open-vm-tools-desktop python3-pip unzip build-essential \
libqt5network5 libqt5core5a libqt5gui5 libqt5widgets5 qtbase5-dev libqt5x11extras5 \
libqt5quick5 libqt5quickwidgets5 libqt5quickparticles5

# 4. Thiết lập Virtual Environment và gdown
echo "📦 Cài đặt gdown và thiết lập Python venv..."
python3 -m venv ~/gdown-venv
source ~/gdown-venv/bin/activate
pip install --no-cache-dir gdown

# 5. Cấu hình vấn đề password (auto-login, sudo không cần password)
echo "🔧 Sửa tất cả vấn đề password..."
sudo passwd -d $USER
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER
sudo tee /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
autologin-session=Lubuntu
EOF

# 6. Kiểm tra và cài đặt Nekobox
echo "🔄 Kiểm tra và cài đặt Nekobox từ Google Drive..."
FILE_ID="1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj"
gdown --id "$FILE_ID" -O nekobox.zip
unzip -o nekobox.zip -d ~/Downloads/nekoray
chmod +x ~/Downloads/nekoray/launcher ~/Downloads/nekoray/nekobox

# 7. Tạo shortcut Desktop cho Nekobox
echo "🖥️ Tạo shortcut Nekobox..."
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

# 8. Pin Nekobox vào taskbar và thêm vào autostart
echo "📌 Pin Nekobox vào taskbar và thêm vào autostart..."
mkdir -p ~/.config/autostart
cp ~/Desktop/nekoray.desktop ~/.config/autostart/nekoray.desktop
chmod +x ~/.config/autostart/nekoray.desktop

# Tùy chỉnh theo môi trường Desktop
if echo "$XDG_CURRENT_DESKTOP" | grep -qi "LXQt"; then
    echo "ℹ️ Lubuntu LXQt detected, pinning Nekobox manually on the panel."
    echo "ℹ️ Bạn có thể kéo shortcut vào panel."
else
    echo "ℹ️ Môi trường khác, Nekobox đã được cài vào autostart."
fi

echo "✅ Nekobox đã được cài đặt thành công!"

# 9. Kiểm tra lại các bước setup
echo "🔍 Kiểm tra lại các bước setup..."
python3 --version
pip3 --version
gdown --version
