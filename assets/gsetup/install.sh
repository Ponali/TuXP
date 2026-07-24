set -e

nm-online -q --timeout=30 || {
    echo "No network"
    exit 1
}

echo "Setting up Windows XP theme (root)"
bash /root/assets/classictheme.sh

echo "Configuring Debian"
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
yes '' | apt --fix-broken install -y >/dev/null 2>/dev/null
dpkg --configure -a >/dev/null

# install user
echo "Installing user"
name=$(yad --entry --text="Username:" --button="OK:0")
pass=$(yad --entry --text="Password:" --button="OK:0")
. ../fakename.sh
fakename=$(getFakeName "$name")
adduser "$fakename" < <(
    echo "$pass"
    echo "$pass"
) >/dev/null 2>/dev/null
usermod -aG sudo "$fakename"
echo -n "$name" > ../realname.txt
echo -n "$fakename" > ../fakename.txt

# Set up Windows XP theme
echo "Setting up Windows XP theme"
sudo -u "$fakename" bash << 'USEREOF'
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/"WinTC Desktop.desktop" << 'EOF'
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=WinTC Desktop
Comment=
Exec=bash -c "xfdesktop --quit;wintc-desktop"
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF
cat > ~/.config/autostart/"WinTC Taskband.desktop" << 'EOF'
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=WinTC Taskband
Comment=
Exec=bash -c "xfce4-panel --quit;wintc-taskband"
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF
cat > ~/.config/autostart/"XCape.desktop" << 'EOF'
[Desktop Entry]
Encoding=UTF-8
Version=0.9.4
Type=Application
Name=XCape
Comment=
Exec=xcape -e 'Super_L=Alt_L|F1'
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF
USEREOF

sudo -u "$fakename" dbus-run-session bash << 'USEREOF'
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>r/startup-notify' -r
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>r' -n -t string -s 'run'
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Alt>F1/startup-notify' -r
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Alt>F1' -n -t string -s 'wintc-taskband --start'

xfconf-query -c xsettings -p /Net/EnableEventSounds -s 'true'
xfconf-query -c xsettings -p /Net/EnableInputFeedbackSounds -s 'true'
xfconf-query -c xsettings -p /Net/SoundThemeName -n -t string -s 'Windows XP Default'
USEREOF
sudo -u "$fakename" dbus-run-session bash < /root/assets/classictheme.sh

# boot to OOBE
echo "Making autologin boot to OOBE"
cat > $TARGET/root/.bash_profile << 'EOF'
if [ "$(tty)" == "/dev/tty1" ]; then
    clear
    cd /root/assets/oobe
    xinit /bin/sh -c 'xfwm4 & exec python3 main.py' >/dev/null 2>/dev/null
fi
EOF


echo "REBOOT-70F8FA016722C807ED0EDF22CD688AFA"
