#!/usr/bin/env bash

SESSION_NAME="scratch"

tmux kill-session -t "${SESSION_NAME}" > /dev/null 2>&1
tmux new-session -d -s "${SESSION_NAME}" "im"
tmux rename-window "irssi"
tmux new-window
tmux rename-window "files"
tmux new-window
tmux rename-window "workspace"
tmux select-window -t "irssi"
tmux attach-session -d
