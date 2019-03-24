#!/usr/bin/env bash

export CLIPBOARD_URL=""
if [[ -n "$1" ]]; then
  CLIPBOARD_URL="$1"
else
  CLIPBOARD_URL=$(xclip -o -selection clipboard)
fi

CLIPBOARD_URL=$(/usr/local/bin/url-cleaner "$CLIPBOARD_URL")

DEFAULT_PROFILE="Default"
FB_PROFILE="Profile 1"
SB_PROFILE="Profile 2"

option_list=("Chromium","Chromium (incognito)","Chromium (throwaway)","Copy to clipboard")
case_str=$(echo ${option_list[@]} | tr ',' '\n' | sort | rofi -dmenu -i -p "How would you like to open: ${CLIPBOARD_URL}" -no-custom)

case "${case_str}" in
  'Copy to clipboard')
    echo -ne "${CLIPBOARD_URL}" | xclip -i -selection clipboard
    ;;
  'Chromium')
    coproc (/usr/bin/chromium-browser --profile-directory="${DEFAULT_PROFILE}" --new-window "${CLIPBOARD_URL}")
    ;;
  'Chromium (incognito)')
    coproc (/usr/bin/chromium-browser --profile-directory="${DEFAULT_PROFILE}" --new-window --incognito "${CLIPBOARD_URL}")
    ;;
  'Chromium (throwaway)')
    coproc (/usr/bin/chromium-browser --temp-profile --new-window "${CLIPBOARD_URL}")
    ;;
  *)
    exit 0
esac
