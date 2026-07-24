#!/usr/bin/env bash

xfconf-query -c xsettings -p /Net/ThemeName -n -t string -s 'Windows Classic style'
xfconf-query -c xsettings -p /Net/IconThemeName -n -t string -s 'luna'
xfconf-query -c xsettings -p /Gtk/FontName -n -t string -s 'Tahoma 8'
xfconf-query -c xfwm4 -p /general/theme -n -t string -s 'Windows Classic style'
xfconf-query -c xfwm4 -p /general/title_font -n -t string -s 'Trebuchet MS Bold 10'
xfconf-query -c xfwm4 -p /general/title_alignment -n -t string -s 'left'
xfconf-query -c xfwm4 -p /general/button_layout -n -t string -s 'O|HMC'
xfconf-query -c xfwm4 -p /general/show_popup_shadow -n -t string -s 'false'
xfconf-query -c xfwm4 -p /general/show_dock_shadow -n -t string -s 'false'
xfconf-query -c xfwm4 -p /general/show_frame_shadow -n -t string -s 'false'
xfconf-query -c xsettings -p /Gtk/CursorThemeName -n -t string -s 'standard-with-shadow'
