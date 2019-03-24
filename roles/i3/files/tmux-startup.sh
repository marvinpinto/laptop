#!/usr/bin/env bash

SESSION_NAME="scratch"

tmux kill-session -t "${SESSION_NAME}" > /dev/null 2>&1

# IRC
tmux new-session -d -s "${SESSION_NAME}" -n irssi -x $(tput cols) -y $(tput lines) "im"

# File manager
tmux new-window -d -n "files"
sleep 1
tmux send-keys -t files "ranger" Enter

# Scratch buffer
tmux new-window -d -n "notepad" vi
tmux send-keys -t notepad ":Scratch" Enter

# Scratch terminal
tmux new-window -d -n "workspace"

tmux select-window -t "irssi"
tmux attach-session -d
