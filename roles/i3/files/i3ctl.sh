#!/bin/sh

I3LOCK='/usr/bin/i3lock --color 333333'

lock() {
    ~/.i3/i3lock.sh
}

case "$1" in
    lock)
        lock
        ;;
    logout)
        i3-msg exit
        ;;
    suspend)
	${I3LOCK} && dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 "org.freedesktop.login1.Manager.Suspend" boolean:true
        ;;
    hibernate)
	${I3LOCK} && dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 "org.freedesktop.login1.Manager.Hibernate" boolean:true
        ;;
    reboot)
	dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 "org.freedesktop.login1.Manager.Reboot" boolean:true
        ;;
    shutdown)
  dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 "org.freedesktop.login1.Manager.PowerOff" boolean:true
        ;;
    enable-screensaver)
  xautolock -detectsleep -time 3 -locker '~/.i3/i3lock.sh' -notify 30 -notifier "notify-send -i info -u normal -t 1000 -- 'Locking screen in 30 seconds'" &
        ;;
    disable-screensaver)
  killall xautolock
        ;;
    *)
        echo "Usage: $0 <lock|logout|suspend|hibernate|reboot|shutdown|enable-screensaver|disable-screensaver>"
        exit 2
esac

exit 0
