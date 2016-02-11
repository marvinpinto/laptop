all:
	@echo "Available targets are: system, dotfiles"
	@exit 1

/tmp/ansible-galaxy-roles:
	mkdir -p /tmp/ansible-galaxy-roles
	ansible-galaxy install -r galaxy-roles.yml -p /tmp/ansible-galaxy-roles

install_ansible:
	@if [ -z "`which ansible-playbook`" ]; then \
	echo "Installing ansible"; \
	sudo apt-add-repository ppa:ansible/ansible; \
	sudo apt-get update; \
	sudo apt-get install ansible; \
	fi

install_git:
	@if [ -z "`which git`" ]; then \
	echo "Installing git"; \
	sudo apt-add-repository ppa:git-core/ppa; \
	sudo apt-get update; \
	sudo apt-get install git; \
	fi

system: install_git install_ansible /tmp/ansible-galaxy-roles
	ANSIBLE_ROLES_PATH=./roles:/tmp/ansible-galaxy-roles ansible-playbook \
		--diff -v \
		--ask-vault-pass \
		-i inventory system.yml

dotfiles:
	ANSIBLE_ROLES_PATH=./roles ansible-playbook \
		--diff -v --ask-vault-pass \
		-i inventory dotfiles.yml
