# set up user accounts
. ../fakename.sh

for i in $(seq 2 5); do
    realn="${!i}"
    faken="$(getFakeName "$realn")"
    adduser "$faken" < <(
        echo ""
        echo ""
    ) >/dev/null 2>/dev/null
done

for i in $(seq 1 5); do
    realn="${!i}"
    faken="$(getFakeName "$realn")"
    if [ "$i" -eq 1 ]; then
        faken=$(cat ../fakename.txt)
    fi
    usermod -c "$realn" "$faken"
done

# remove autologin
rm /etc/systemd/system/getty@tty1.service.d/override.conf
rm /root/.bash_profile
sudo systemctl set-default graphical.target >/dev/null
systemctl enable lightdm >/dev/null

# log out to lightdm
loginctl terminate-session "$XDG_SESSION_ID"
