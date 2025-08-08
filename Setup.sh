#!/bin/bash

# ===================================================================
# SCRIPT TỔNG HỢP: Cài đặt Browser + VM Setup + Fix Password Issues
# Tương thích với Ubuntu/Lubuntu 24.04
# Thứ tự: ChromeOld.sh -> SetupVm.bash -> fix_password_issues.sh
# ===================================================================

set -e  # Stop if any command fails

echo "🚀 BẮT ĐẦU SCRIPT TỔNG HỢP - Ubuntu/Lubuntu 24.04"
echo "📋 Thứ tự thực hiện:"
echo "   1️⃣ Cài đặt Chrome cũ"
echo "   2️⃣ Setup VM và Nekobox"
echo "   3️⃣ Fix tất cả vấn đề password"
echo ""

# ===================================================================
# PHẦN 1: CHROMEOLD.SH - CÀI ĐẶT BROWSER CŨ
# ===================================================================

echo "🌐 === PHẦN 1: CÀI ĐẶT CHROME CŨ ==="

# Cài đặt python3-venv trước khi tạo virtual environment
echo "📦 Cài đặt python3-venv..."
sudo apt update
sudo apt install -y python3-venv python3-pip

# Tự cài Python venv và gdown
if [[ ! -d "$HOME/gdown-venv" ]]; then
    echo "📦 Đang tạo venv Python và cài gdown..."
    python3 -m venv ~/gdown-venv
fi

source ~/gdown-venv/bin/activate

# Cài gdown trong venv (đảm bảo luôn có)
pip install --no-cache-dir gdown

# Cấu hình Google Drive Folder ID cho Chrome
CHROME_DRIVE_ID="1tD0XPj-t5C7p9ByV3RLg-qcHaYYSXAj1"

DOWNLOAD_DIR="$HOME/browser_temp"
mkdir -p "$DOWNLOAD_DIR" && cd "$DOWNLOAD_DIR"

# Chỉ cài Chrome
echo "📥 Đang cài đặt Google Chrome cũ..."
DRIVE_ID="$CHROME_DRIVE_ID"
BTYPE="chrome"

# Tải toàn bộ folder từ Google Drive
echo "📥 Đang tải toàn bộ folder Chrome từ Google Drive..."
gdown --folder "https://drive.google.com/drive/folders/$DRIVE_ID" --no-cookies

# Liệt kê file Chrome .deb tải về
echo "🔍 Danh sách file Chrome tải về:"
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

# Xóa file không được chọn để tiết kiệm dung lượng
echo "🧹 Dọn dẹp file không dùng..."
find "$DOWNLOAD_DIR" -type f ! -name "$(basename "$FILE_SELECT")" -delete

# Gỡ bản Chrome mặc định
echo "🗑️ Gỡ Chrome mặc định..."
sudo apt remove -y google-chrome-stable || true

# Cài đặt Chrome và khóa cập nhật
echo "🚀 Đang cài Chrome..."
sudo dpkg -i "$FILE_SELECT"
sudo apt -f install -y
sudo apt-mark hold google-chrome-stable
sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/google-chrome.list 2>/dev/null

# Tắt update nội bộ của Chrome
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

# Tạo shortcut Chrome
echo "🎨 Tạo shortcut Chrome..."
cat <<EOF3 > ~/.local/share/applications/browser_custom.desktop
[Desktop Entry]
Name=Google Chrome (Custom)
Exec=/usr/bin/google-chrome-stable %U
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF3

# Pin vào taskbar
if command -v gsettings &>/dev/null; then
    gio set ~/.local/share/applications/browser_custom.desktop metadata::trusted true 2>/dev/null
    gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed "s/]$/, 'browser_custom.desktop']/")"
else
    echo "ℹ️ Trên Lubuntu (LXQt), hãy nhấp phải biểu tượng trong menu -> 'Pin to Panel'."
fi

echo "✅ PHẦN 1 HOÀN TẤT! Chrome đã được cài, khóa update và tắt update nội bộ."
echo ""

# Deactivate venv trước khi chuyển sang phần 2
deactivate

# ===================================================================
# PHẦN 2: SETUPVM.BASH - SETUP VM VÀ NEKOBOX
# ===================================================================

echo "⚙️ === PHẦN 2: SETUP VM VÀ NEKOBOX ==="

# Update & Upgrade
echo "🔄 Updating system packages..."
sudo add-apt-repository universe -y || true
sudo apt update && sudo apt upgrade -y

# Install Open VM Tools
echo "📦 Installing Open VM Tools..."
sudo apt install -y open-vm-tools open-vm-tools-desktop || echo "⚠️ Warning: Open VM Tools not found for this Ubuntu version."

# Install gdown and unzip
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

# Install core build tools and Qt5 libraries
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

# Prepare Nekoray folder
echo "📂 Preparing Nekoray folder..."
rm -rf ~/Downloads/nekoray
mkdir -p ~/Downloads/nekoray

# Download Nekobox ZIP from Google Drive
echo "⬇️ Downloading Nekobox from Google Drive..."
cd ~/Downloads

# Thay ID này bằng ID thực tế của file Nekobox trên Google Drive!
FILE_ID="1ZnubkMQL06AWZoqaHzRHtJTEtBXZ8Pdj"  
gdown --id "$FILE_ID" -O nekobox.zip || { echo "❌ Download failed! Check Google Drive file ID."; exit 1; }

# Extract Nekobox
echo "📂 Extracting Nekobox..."
unzip -o nekobox.zip -d ~/Downloads/nekoray

# Handle nested folders
inner_dir=$(find ~/Downloads/nekoray -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ "$inner_dir" != "" ] && [ "$inner_dir" != "$HOME/Downloads/nekoray" ]; then
    echo "📂 Adjusting folder structure..."
    mv "$inner_dir"/* ~/Downloads/nekoray/
    rm -rf "$inner_dir"
fi

# Grant execution permissions
echo "🔑 Setting execution permissions..."
cd ~/Downloads/nekoray
chmod +x launcher nekobox nekobox_core || echo "⚠️ Some files not found, skipping chmod."

# Create desktop shortcut
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

# Launch Nekobox
echo "🚀 Launching Nekobox..."
./nekobox || echo "⚠️ Unable to launch Nekobox automatically. Start manually from ~/Downloads/nekoray."

echo "✅ PHẦN 2 HOÀN TẤT! Setup VM và Nekobox thành công!"
echo ""

# Deactivate venv trước khi chuyển sang phần 3
deactivate

# ===================================================================
# PHẦN 3: FIX_PASSWORD_ISSUES.SH - SỬA VẤN ĐỀ PASSWORD
# ===================================================================

echo "🔧 === PHẦN 3: SỬA TẤT CẢ VẤN ĐỀ PASSWORD ==="

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

echo "✅ PHẦN 3 HOÀN TẤT! Đã sửa tất cả vấn đề password!"
echo ""

# ===================================================================
# KẾT THÚC SCRIPT TỔNG HỢP
# ===================================================================

echo "🎉 === HOÀN TẤT TẤT CẢ 3 PHẦN ==="
echo ""
echo "📋 Tóm tắt những gì đã thực hiện:"
echo "   ✅ Phần 1: Cài đặt Chrome cũ và khóa update"
echo "   ✅ Phần 2: Setup VM tools và Nekobox"
echo "   ✅ Phần 3: Fix tất cả vấn đề password"
echo ""
echo "🔄 BẮT BUỘC PHẢI KHỞI ĐỘNG LẠI để áp dụng:"
echo "   sudo reboot"
echo ""
echo "📋 Sau khi reboot:"
echo "   ✅ Máy tự động vào desktop (không cần password)"
echo "   ✅ Sudo commands chạy không cần password"
echo "   ✅ Chrome/Firefox mở không hỏi master password"
echo "   ✅ Nekobox tự động khởi động"
echo ""
read -p "🔄 Khởi động lại ngay bây giờ? (y/n): " -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo reboot
fi
