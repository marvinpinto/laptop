# Laptop

[![Build Status](https://img.shields.io/travis/marvinpinto/laptop/master.svg?style=flat-square)](https://travis-ci.org/marvinpinto/laptop)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square)](LICENSE.txt)

This is the configuration I use to bootstrap and maintain my development
machines. I have automated the bulk of this over the years and it's helped me
maintain a reproducible development machine.

Look through my
[osx-bootstrapping](https://github.com/marvinpinto/osx-bootstrapping)
repository for a previous incantation of this setup.



## Travis CI

You will also notice that this repository is linked into [Travis
CI](https://travis-ci.org/marvinpinto/laptop) and builds are kicked off
automatically on PRs and such.

The idea here is that if this successfully builds in Travis, there's a
reasonable chance it will build when it comes time to bootstrap my laptop
again.



## Manual Preparation

- Ensure that the Fn keys at the top act as actual Function keys by default,
  and not their Lenovo counterparts. This will need to be done in the bios.
- Ensure that VTx virtualization has been enabled. This will also need to be
done in the bios.



## Bootstrap the Dell T1700 from scratch

1. Boot up the Dell T1700 with the [netboot.xyz](https://netboot.xyz) USB key
   in place. Ensure that an ethernet cable is connected.
1. At the boot screen, hit F12 and select `USB Storage Device`.
1. Install Ubuntu 16.04. When prompted, supply
   `http://cdn.rawgit.com/marvinpinto/laptop/master/ubuntu-mp-desktop-preseed.cfg`
   as the preseed URL.
1. After the reboot, hit Ctrl + Alt + F1 to get to terminal.
1. Run the following curl/bash incantation to get everything going:
    ```bash
    export ANSIBLE_VAULT_PASSWORD=sekrit
    bash -xec "$(curl -L https://raw.githubusercontent.com/marvinpinto/laptop/master/bootstrap.sh)"
    ```
1. Reboot the machine after everything installs correctly.
1. Follow the instructions to restore the GPG keys.
1. Follow the instructions to restore all the data files.
1. Follow the instructions to restore all the base project directories.
1. Follow the instructions to initialize the 1password CLI.
1. Configure `wicd-curses` to connect to the WiFi network.
1. Reboot the machine one last time.



## Bootstrap the Lenovo X1 Carbon from scratch

To be updated..



## Restoring GPG keys

Configure the yubikey to work on the new machine:
``` text
$ gpg --card-edit
gpg/card> fetch
gpg/card> quit
```

Mark the GPG key as ultimately trusted:

``` text
$ gpg --edit-key 52654E6EB0BB564B
gpg> trust
Your decision? 5
Do you really want to set this key to ultimate trust? (y/N) y
gpg> quit
```



## Restoring files

Use the rclone wrapper to copy/sync all the data files:

``` bash
$ acd-backup "down"
```



## Initialize the 1password CLI
``` bash
$ bootstrap-op
```



## Restoring project directories

Use the git wrapper script to restore all the base project directories:

``` bash
$ bootstrap-projects
```



## Updating a user config file

Make any changes as needed and then run `make dotfiles` to apply them locally.



## Adding or removing a system application

Similar to updating a config file, adding/removing system applications (and
    their configuration) will involve tweaking the ansible roles linked to this
repository.

Make the changes as needed and then run:

```bash
make system
```
