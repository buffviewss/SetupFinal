#!/bin/bash

# === CÀI CHROME ===
#!/bin/bash

# === Tự cài Python venv và gdown ===
if [[ ! -d "$HOME/gdown-venv" ]]; then
    echo "📦 Đang tạo venv Python và cài gdown..."
    python3 -m venv ~/gdown-venv
fi

source ~/gdown-venv/bin/activate

# Cài gdown trong venv (đảm bảo luôn có)
pip install --no-cache-dir gdown

# === Cấu hình Google Drive Folder ID ===
CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"
FIREFOX_DRIVE_ID="1CeMNJTLgfsaFkcroOh1xpxFC-uz9HrLb"

DOWNLOAD_DIR="$HOME/browser_temp"
mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

# === Chọn trình duyệt ===
BTYPE="chrome"
DRIVE_ID="$CHROME_DRIVE_ID"
echo "📥 Đang tải toàn bộ folder $BTYPE từ Google Drive..."
gdown --folder "https://drive.google.com/drive/folders/$DRIVE_ID" --no-cookies

# === Liệt kê file tải về ===
echo "🔍 Danh sách file tải về:"
if [[ $BTYPE == "chrome" ]]; then
    FILE_LIST=$(find "$DOWNLOAD_DIR" -type f -name "*.deb")
else
    FILE_LIST=$(find "$DOWNLOAD_DIR" -type f)
fi

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

# === Gỡ bản mặc định ===
echo "🗑️ Gỡ bản mặc định..."
if [[ $BTYPE == "chrome" ]]; then
    sudo apt remove -y google-chrome-stable || true


# === SETUP VM & NEKOBOX ===
#!/bin/bash

# =========================
# Setup Nekobox on Ubuntu/Lubuntu (Fixed)
# =========================

set -e  # Stop if any command fails

# 1. Update & Upgrade
echo "🔄 Updating system packages..."
sudo add-apt-repository universe -y || true
sudo apt update && sudo apt upgrade -y

# 1.1 Install Google Chrome (Ubuntu/Lubuntu 24.04 compatible)
# echo "🌐 Installing Google Chrome..."
# if ! command -v google-chrome &> /dev/null; then
#     wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb
    
#     # Cài đặt Chrome với apt để xử lý phụ thuộc
#     sudo apt install -y /tmp/google-chrome.deb || {
#         echo "⚠️ Chrome install failed. Fixing dependencies..."
#         sudo apt --fix-broken install -y
#         sudo apt install -y /tmp/google-chrome.deb
#     }
#     rm /tmp/google-chrome.deb
#     echo "✅ Google Chrome installed successfully!"
# else
#     echo "✅ Google Chrome is already installed."
# fi

# # 1.2 Create Google Chrome desktop shortcut
# echo "🖥️ Creating Google Chrome desktop shortcut..."
# cat <<EOF > ~/Desktop/google-chrome.desktop
# [Desktop Entry]
# Version=1.0
# Name=Google Chrome
# Comment=Browse the web
# Exec=/usr/bin/google-chrome-stable
# Icon=/usr/share/icons/hicolor/128x128/apps/google-chrome.png
# Terminal=false
# Type=Application
# Categories=Network;WebBrowser;
# EOF

# chmod +x ~/Desktop/google-chrome.desktop

# # 1.3 Autostart Google Chrome (optional)
# mkdir -p ~/.config/autostart
# cp ~/Desktop/google-chrome.desktop ~/.config/autostart/google-chrome.desktop
# chmod +x ~/.config/autostart/google-chrome.desktop

# echo "✅ Google Chrome shortcut created and added to autostart."


# 2. Install Open VM Tools
echo "📦 Installing Open VM Tools..."
sudo apt install -y open-vm-tools open-vm-tools-desktop || echo "⚠️ Warning: Open VM Tools not found for this Ubuntu version."

# 3. Install gdown and unzip
echo "📦 Installing gdown & unzip..."
sudo apt install -y python3-pip unzip
if ! command -v pip3 &> /dev/null; then
    echo "⚠️ pip3 missing, installing..."
    sudo apt install -y python3-pip
fi
sudo apt install python3-venv -y
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install --upgrade pip gdown


# 4. Install core build tools and Qt5 libraries
echo "📦 Installing build tools and Qt5 libraries..."
sudo apt install -y build-essential \
libqt5network5 \
libqt5core5a \
libqt5gui5 \
libqt5widgets5 \
qtbase5-dev \
libqt5x11extras5 \
libqt5quick5 \
libqt5quickwidgets5 \
libqt5quickparticles5

# 5. Prepare Nekoray folder
echo "📂 Preparing Nekoray folder..."
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
# Pin vào taskbar theo môi trường Desktop
if echo "$XDG_CURRENT_DESKTOP" | grep -qi "GNOME"; then
    echo "📌 Ubuntu GNOME detected - pinning Nekobox to taskbar..."
    gsettings set org.gnome.shell favorite-apps \
    "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'nekoray.desktop']/")" || true
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


echo ""
echo "🔍 Running post-setup checks..."

# 1. Kiểm tra gói APT
echo "📦 Checking APT packages..."
for pkg in open-vm-tools open-vm-tools-desktop python3-pip unzip build-essential qtbase5-dev; do
    if dpkg -l | grep -q "^ii\s*$pkg"; then
        echo "✅ $pkg installed"
    else
        echo "❌ $pkg missing"
    fi
done

# 2. Kiểm tra Python và pip
echo "🐍 Python & pip:"
python3 --version
pip3 --version

# 3. Kiểm tra gdown
echo "⬇️ Checking gdown..."
if python3 -m pip show gdown >/dev/null 2>&1; then
    echo "✅ gdown installed"
else
    echo "❌ gdown missing"
fi

# 4. Kiểm tra thư mục Nekoray
echo "📂 Checking Nekoray folder..."
if [ -d "$HOME/Downloads/nekoray" ]; then
    echo "✅ Nekoray folder exists"
else
    echo "❌ Nekoray folder missing"
fi

# 5. Kiểm tra shortcut Desktop
echo "🖥️ Checking Desktop shortcut..."
if [ -f "$HOME/Desktop/nekoray.desktop" ]; then
    echo "✅ Desktop shortcut exists"
else
    echo "❌ Desktop shortcut missing"
fi

echo "🔎 Post-setup check completed!"



# === SỬA PASSWORD & AUTO LOGIN ===
#!/bin/bash

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

# 10. CẤU HÌNH FIREFOX KHÔNG YÊU CẦU PASSWORD
echo "🦊 Cấu hình Firefox..."
# Tạo profile Firefox nếu chưa có
firefox -CreateProfile "default" 2>/dev/null || true
sleep 2
pkill firefox 2>/dev/null || true

# Tìm Firefox profile directory
FF_PROFILE=$(find ~/.mozilla/firefox -name "*.default*" -type d 2>/dev/null | head -n 1)
if [[ -n "$FF_PROFILE" ]]; then
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
echo ""
read -p "🔄 Khởi động lại ngay bây giờ? (y/n): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
fi
