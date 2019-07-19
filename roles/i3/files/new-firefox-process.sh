#!/usr/bin/env bash
set -e
PROFILEDIR=$(mktemp -p /tmp -d tmp-fx-profile.XXXXXX.d)
DEFAULT_PROFILE=$(grep "Default=.*default-.*" ${HOME}/.mozilla/firefox/profiles.ini | cut -d = -f2)

cp -R ${HOME}/.mozilla/firefox/${DEFAULT_PROFILE}/* ${PROFILEDIR}/

/usr/bin/firefox -profile $PROFILEDIR --no-remote --private-window
rm -rf "$PROFILEDIR"
