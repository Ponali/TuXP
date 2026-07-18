nm-online -q --timeout=30 || {
    echo "No network"
    exit 1
}

echo "Configuring Debian"
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
dpkg --configure -a

echo "Installing user"

# install user
name=$(yad --entry --text="Username:" --button="OK:0")
pass=$(yad --entry --text="Password:" --button="OK:0")
. ../fakename.sh
adduser "$(getFakeName "$name")" < <(
    echo "$pass"
    echo "$pass"
) >/dev/null 2>/dev/null
usermod -aG sudo "$name"
echo "$name" > ../username.txt

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
