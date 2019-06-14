ifndef TRAVIS
	ci_args = --become --ask-become-pass
else
	ci_args =
endif

all:
	@echo "Available targets are: system, dotfiles"
	@exit 1

/tmp/ansible-galaxy-roles:
	mkdir -p /tmp/ansible-galaxy-roles
	ansible-galaxy install -r galaxy-roles.yml -p /tmp/ansible-galaxy-roles

system: /tmp/ansible-galaxy-roles
	ANSIBLE_ROLES_PATH=./roles:/tmp/ansible-galaxy-roles ansible-playbook \
		--vault-password-file=vault_pass.sh \
		--connection=local \
		--inventory=127.0.0.1, \
		$(ci_args) \
		system.yml

dotfiles:
	ANSIBLE_ROLES_PATH=./roles ansible-playbook \
		--vault-password-file=vault_pass.sh \
		--connection=local \
		--inventory=127.0.0.1, \
		dotfiles.yml
