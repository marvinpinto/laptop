# Laptop

This is the config I use to bootstrap and maintain my Lenovo X1 Carbon laptop.
I have automated the bulk of this over the years and it has greatly helped me
maintain my sanity.

For a previous incantation of this, have a look through my
[osx-bootstrapping](https://github.com/marvinpinto/osx-bootstrapping)
repository.

## Scenarios

The three main scenarios where this comes into play are:

- [Bootstrapping from scratch](#bootstrapping-from-scratch)
- [Updating a user config file (i.e. dotfile)](#updating-a-user-config-file)
- [Installing/removing a system application](#Adding-or-removing-a-system-application)


## Bootstrapping from scratch

In this scenario, I'm either setting up a brand new laptop or rebuilding the
current laptop from scratch.

- Boot up the Lenovo X1 Carbon with the USB key in place.

- At the boot screen, Hit "enter" for more boot options, then hit F12 and
select the appropriate USB boot device.

- Install Ubuntu 14.04 LTS, desktop edition.

- After the reboot, hit Ctrl + Alt + F2 to get to terminal.

- At this point make sure that **ethernet** Internet access is available. It
makes things a lot simpler.

- Then run this wonderful curl/bash incantation that will get everything going:
  ```
  bash -xec "$(curl -L https://raw.githubusercontent.com/marvinpinto/laptop/master/bootstrap.sh)"
  ```

- Assuming everything installed correctly, reboot the machine.

#### Initial manual setup

- When the Ubuntu login screen comes up, select `i3` as the desktop manager and
login

- After logging in, start and install Dropbox as follows:
  ```
  /usr/bin/dropbox start -i
  ```

- Ensure that the Fn keys at the top act as actual Function keys by default,
  and not their lenovo counterparts. This will need to be done in the bios.

This should bring the machine up to a useable state with all my apps and config
in place!


## Updating a user config file

In this scenario, I'm either adding a new config file (dotfile) to my setup or
tweaking an existing one. Pretty simple.

Make the changes as needed and then run: `make dotfiles`

This will take care of putting all the files in the correct places, setting
permissions, that sort of thing.


## Adding or removing a system application

Similar to adding a config file, adding/removing system applications (and their
configuration) will involve tweaking the ansible roles linked to this
repository.

After that is done a simple `make system` should do it,
