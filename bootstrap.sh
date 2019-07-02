#!/bin/bash -e

export DEBIAN_FRONTEND=noninteractive
SUDO="sudo -E"

if [ "$TRAVIS" == "true" ]; then
  apt-get -qq update && apt-get install -y curl sudo
fi

$SUDO apt-get install -qq -y software-properties-common build-essential

if [ "$TRAVIS" == "true" ]; then
  echo "Bootstrapping Travis CI"
  $SUDO useradd marvin
  $SUDO mkdir -p /home/marvin
  $SUDO chown -R marvin: /home/marvin
  $SUDO apt-get -qq update

  # Remove /sbin/initctl within the docker container so that Ansible uses
  # 'sysvinit' for the 'service' module
  $SUDO rm -rf /sbin/initctl

  $SUDO ln -s -f /bin/true /usr/bin/chfn
  $SUDO apt-get install -qq -y -o Dpkg::Options::=--force-confnew network-manager ubuntu-desktop
fi

echo "Installing git"
$SUDO apt-add-repository -y ppa:git-core/ppa
$SUDO apt-get -qq update
$SUDO apt-get -y install -qq git

echo "Installing ansible"
$SUDO apt-add-repository -y ppa:ansible/ansible
$SUDO apt-get -qq update
$SUDO apt-get install -qq -y ansible

# Only clone if this isn't being built on travis
if [ -z "$TRAVIS" ]; then
  echo "Cloning https://github.com/marvinpinto/laptop.git"
  cd /tmp
  $SUDO rm -rf laptop
  git clone https://github.com/marvinpinto/laptop.git
fi

echo "Bootstrapping system"
if [ -z "$TRAVIS" ]; then
  cd laptop
  git checkout origin/master
fi
if [ "$TRAVIS" == "true" ]; then
  $SUDO make system
else
  make system
fi

echo "Installing dotfiles"
$SUDO rm -rf ~/.ansible
if [ "$TRAVIS" == "true" ]; then
  $SUDO make dotfiles
else
  make dotfiles
fi

echo "Upgrading Ubuntu"
if [ -z "$TRAVIS" ]; then
  cd /tmp
fi
$SUDO apt-get -qq update
$SUDO apt-get -qq -y -o Dpkg::Options::=--force-confnew dist-upgrade
$SUDO apt-get autoremove -y --purge

echo "Last time for good measure"
if [ -z "$TRAVIS" ]; then
  cd /tmp/laptop
fi
if [ "$TRAVIS" == "true" ]; then
  $SUDO make system
else
  make system
fi
