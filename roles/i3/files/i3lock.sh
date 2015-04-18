#!/bin/bash
# /usr/bin/scrot /tmp/screen_locked.png
# /usr/bin/convert /tmp/screen_locked.png -blur 2x2 /tmp/screen_locked2.png
# /usr/bin/i3lock -i /tmp/screen_locked2.png

# Take a screenshot
/usr/bin/scrot /tmp/screen_locked.png

# Pixellate it 10x
mogrify -scale 10% -scale 1000% /tmp/screen_locked.png

# Lock screen displaying this image.
i3lock -i /tmp/screen_locked.png

# Turn the screen off after a delay.
sleep 60; pgrep i3lock && xset dpms force off

