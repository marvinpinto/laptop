ifneq ("$(wildcard ${HOME}/projects/ansible-roles/.git)","")
    ROLESDIR := ${HOME}/projects/ansible-roles
    CLONEROLES := false
else
    ROLESDIR := /tmp/ansible-roles
    CLONEROLES := true
endif

all:
	@echo "Available targets are: system, dotfiles"
	@exit 1

cloneroles:
	@if [ "$(CLONEROLES)" = "true" ]; then \
	echo "cloning https://github.com/marvinpinto/ansible-roles.git"; \
	rm -rf $(ROLESDIR); \
	git clone https://github.com/marvinpinto/ansible-roles.git $(ROLESDIR); \
	fi

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

system: cloneroles install_git install_ansible
	ANSIBLE_ROLES_PATH=$(ROLESDIR): ansible-playbook \
										 --diff -v --ask-sudo-pass \
										 --ask-vault-pass \
										 -i inventory system.yml

dotfiles: cloneroles
	ANSIBLE_ROLES_PATH=$(ROLESDIR):./roles ansible-playbook \
										 --diff -v --ask-vault-pass \
										 -i inventory dotfiles.yml
