#!/usr/bin/env bash

SLEEP_DURATION=2

notify-send -i info -u normal -t 1000 -- 'Restoring basic window layout'
i3-msg 'workspace primary; exec xterm -en utf-8;'
sleep ${SLEEP_DURATION}
i3-msg 'workspace research; exec chromium-browser --profile-directory="Default";'
sleep ${SLEEP_DURATION}
i3-msg 'workspace sb; exec chromium-browser --profile-directory="Profile 2";'
sleep ${SLEEP_DURATION}
i3-msg 'workspace browser; exec chromium-browser --profile-directory="Default";'
sleep ${SLEEP_DURATION}
i3-msg 'workspace sbchrome; exec google-chrome;'
sleep ${SLEEP_DURATION}
i3-msg 'workspace social; exec chromium-browser --profile-directory="Default";'
sleep ${SLEEP_DURATION}
i3-msg 'workspace primary;'
sleep ${SLEEP_DURATION}
notify-send -i info -u normal -t 5000 -- 'Window layout restore complete'
