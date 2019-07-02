#!/bin/bash -e

export DOCKER_IMG="ubuntu:16.04"
export TRAVIS="true"
export DOCKER_CONTAINER=ubuntu-container
export DEBIAN_FRONTEND=noninteractive
docker pull ${DOCKER_IMG}

docker rm -f "${DOCKER_CONTAINER}" || true

export ANSIBLE_VAULT_PASSWORD=$(op get item --vault="Private" "development_secrets" | jq '.details.sections[].fields[] | select(.t == "github.com/marvinpinto/laptop/ansible_vault_passphrase").v' | tr -d '"')

docker run -dit --userns=host --privileged --volume "${PWD}:/root/laptop" --workdir /root/laptop --env ANSIBLE_VAULT_PASSWORD --env TRAVIS --env DEBIAN_FRONTEND --name "${DOCKER_CONTAINER}" --user root "${DOCKER_IMG}"

docker exec -it "${DOCKER_CONTAINER}" sh -c /root/laptop/bootstrap.sh
docker rm -f "${DOCKER_CONTAINER}"
