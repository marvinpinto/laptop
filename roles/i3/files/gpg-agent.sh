#!/bin/bash

if [ "$(lsb_release --release --short)" == "16.04" ]; then
  gpgconf --kill gpg-agent
  gpgconf --launch gpg-agent
else
  # Start the GnuPG agent and enable OpenSSH agent emulation
  gnupginf="${HOME}/.gnupg/gpg-agent-info"

  if pgrep -x -u "${USER}" gpg-agent >/dev/null 2>&1; then
      eval `cat $gnupginf`
      eval `cut -d= -f1 $gnupginf | xargs echo export`
  else
      eval `gpg-agent --enable-ssh-support --sh --daemon --write-env-file "$gnupginf"`
  fi
fi
