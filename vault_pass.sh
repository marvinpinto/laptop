#!/bin/sh
if [ -n "$ANSIBLE_VAULT_PASSWORD" ]; then
  printf "%s" "$ANSIBLE_VAULT_PASSWORD"
else
  gpg2 --batch --use-agent --decrypt vault_passphrase.gpg
fi
