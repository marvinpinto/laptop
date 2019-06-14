#!/bin/sh
if [ -n "$ANSIBLE_VAULT_PASSWORD" ]; then
  printf "%s" "$ANSIBLE_VAULT_PASSWORD"
else
  op get item --vault="Private" "development_secrets" | jq '.details.sections[].fields[] | select(.t == "github.com/marvinpinto/laptop/ansible_vault_passphrase").v' | tr -d '"'
fi
