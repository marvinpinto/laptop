#!/bin/bash -xe

export DEBIAN_FRONTEND=noninteractive

echo "Installing git"
sudo apt-add-repository -y ppa:git-core/ppa
sudo apt-get -qq update
sudo apt-get -y install git

echo "Installing ansible"
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get -qq update
sudo apt-get install -y ansible

echo "Cloning https://github.com/marvinpinto/laptop.git"
cd /tmp
sudo rm -rf laptop
git clone https://github.com/marvinpinto/laptop.git

echo "Bootstrapping system"
cd laptop
sudo make system

echo "Installing dotfiles"
sudo rm -rf ~/.ansible
make dotfiles

echo "Upgrading Ubuntu"
cd /tmp
sudo apt-get -qq update
sudo apt-get -y dist-upgrade
sudo apt-get autoremove -y --purge

echo "Last time for good measure"
cd /tmp/laptop
sudo make system
