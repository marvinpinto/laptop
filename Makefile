all:
	@echo "Available targets are: system, dotfiles"
	@exit 1

/tmp/ansible-galaxy-roles:
	mkdir -p /tmp/ansible-galaxy-roles
	ansible-galaxy install -r galaxy-roles.yml -p /tmp/ansible-galaxy-roles

system: /tmp/ansible-galaxy-roles
	ANSIBLE_ROLES_PATH=./roles:/tmp/ansible-galaxy-roles ansible-playbook \
		--vault-password-file=vault_pass.py \
		-i inventory system.yml

dotfiles:
	ANSIBLE_ROLES_PATH=./roles ansible-playbook \
		--vault-password-file=vault_pass.py \
		-i inventory dotfiles.yml
