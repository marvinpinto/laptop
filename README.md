# Laptop

This is the config I use to bootstrap and maintain my Lenovo X1 Carbon laptop.
I have automated the bulk of this over the years and it has greatly helped me
maintain my sanity.

For a previous incantation of this, have a look through my
[osx-bootstrapping](https://github.com/marvinpinto/osx-bootstrapping)
repository.

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
  bash -xec "$(curl -L https://raw.githubusercontent.com/marvinpinto/dotfiles/master/bootstrap.sh)"
  ```

- Assuming everything installed correctly, reboot the machine.

#### Initial manual setup

- When the Ubuntu login screen comes up, select `i3` as the desktop manager and
login

- After logging in, start and install Dropbox as follows:
  ```
  /usr/bin/dropbox start -i
  ```

This should bring the machine up to a useable state with all my apps and config
in place!
