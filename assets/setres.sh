RES=${1}x${2}
OUTPUT=$(xrandr | awk '
/ primary/ {print $1; exit}
/ connected/ {print $1; exit}
')
xrandr --output "$OUTPUT" --mode $RES
if (xrandr | grep -F eDP-1 | grep -F $RES)>/dev/null 2>/dev/null; then
    echo xrandr --newmode $(cvt $1 $2 60 | tail -n 1 | sed 's/Modeline//') | bash
    xrandr --addmode "$OUTPUT" ${RES}_60.00
    xrandr --output "$OUTPUT" --mode ${RES}_60.00
fi
