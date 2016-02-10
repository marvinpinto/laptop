#!/bin/bash

workspace1_laptop() {
  i3-msg 'workspace 1; append_layout /home/marvin/.i3/workspace-1-laptop.json'
  i3-msg 'workspace 1; exec xterm'
  i3-msg 'workspace 1; exec google-chrome'
}

workspace2_laptop() {
  i3-msg 'workspace 2; append_layout /home/marvin/.i3/workspace-2-laptop.json'
  i3-msg 'workspace 2; exec xterm'
  i3-msg 'workspace 2; exec xterm'
  i3-msg 'workspace 2; exec xterm'
}

workspace2_monitor() {
  i3-msg 'workspace 2; append_layout /home/marvin/.i3/workspace-2-monitor.json'
  i3-msg 'workspace 2; exec xterm'
  i3-msg 'workspace 2; exec xterm'
  i3-msg 'workspace 2; exec xterm'
  i3-msg 'workspace 2; exec xterm'
}

workspace3_laptop() {
  i3-msg 'workspace 3; append_layout /home/marvin/.i3/workspace-3-laptop.json'
  i3-msg 'workspace 3; exec google-chrome'
}

workspace3_monitor() {
  i3-msg 'workspace 3; append_layout /home/marvin/.i3/workspace-3-monitor.json'
  i3-msg 'workspace 3; exec google-chrome'
  i3-msg 'workspace 3; exec google-chrome'
}

case "$1" in
  laptop)
    workspace1_laptop
    workspace2_laptop
    workspace3_laptop
    ;;
  monitor)
    workspace1_laptop
    workspace2_monitor
    workspace3_monitor
    ;;
  *)
    echo "Usage: $0 <laptop|monitor>"
    exit 2
esac

exit 0
