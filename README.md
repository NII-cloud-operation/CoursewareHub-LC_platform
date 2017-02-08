## Clone repository:

```
$ git clone git@github.com:axsh/jupyter-platform-dev.git
$ cd jupyter-platform-dev
```

## Build on KVM

The directory ``~/ubuntu-image-resources`` must exist in the home directory
and contain the following files:

```
$ cd ~/
$ cd ubuntu-image-resources/
$ ls -l
total 580760
-rw-r--r-- 8 k-oyakata k-oyakata 594675764 Dec  6 23:16 ubuntu-14-instance-build.img-sshkeys-update-upgrade.tar.gz
-rw-r--r-- 4 k-oyakata k-oyakata      1675 Jul 15  2016 ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshkey
-rw-r--r-- 4 k-oyakata k-oyakata         7 Jul 15  2016 ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshuser
```

The ``*.tar.gz`` file contains Ubuntu 14.04.1 LTS with a 242GB root
file system.  It was made by doing a fresh install from an ISO, then
``apt-get update``, then ``apt-get upgrade``.  Finally, a public key
was placed in /home/ubuntu/.ssh/authorized_keys.  The private part of
the key pair is in the ``*.sshkey``.  The ``*.sshuer`` file just
contains the string "ubuntu", because that is the user name to use
when doing ssh to a VM booted from the image.

The next step is to make a build directory by using the toplevel-kvm-build.sh-new
in the repository like this:
```
$ ./ind-steps/build-jh-environment/toplevel-kvm-build.sh-new /some/directory/path/buildname
```
Be sure to substitute ``/some/directory/path`` with a path for a disk that
has 60GB or so of free disk space.

The above step quickly creates a new directory tree that includes this structure:
```
$ cd /some/directory/path/buildname
$ find -name datadir.conf
./datadir.conf
./jhvmdir/datadir.conf
./jhvmdir-hub/datadir.conf
./jhvmdir-node1/datadir.conf
./jhvmdir-node2/datadir.conf
```

Each ``jhvmdir*`` represents one of the 4 VMs for the build, and its ``datadir.conf``
gives configuration information used during building.  Additional information from
the build will be added to the appropriate ``datadir.conf``.

The actual build is done by running a script that is now inside the
build directory:

```
$ /some/directory/path/buildname/toplevel-kvm-build.sh do
```
The whole build takes about 60 to 90 minutes.

The following command can be used to verify which steps of the
build have completed. (The same as above, just change ``do`` to ``check``)

```
$ /some/directory/path/buildname/toplevel-kvm-build.sh check
```

The build defaults to 2 docker swarm nodes.  This can be changed
with the ``nodecount`` environment variable.

```
$ nodecount=3 ./ind-steps/build-jh-environment/toplevel-kvm-build.sh-new /some/directory/path/buildname
```

## Build on AWS

Install awscli:  http://docs.aws.amazon.com/cli/latest/userguide/installing.html
Also make sure ``.aws/config`` and ``.aws/credentials`` are set up correctly.

Then:
```
$ ./ind-steps/build-jh-environment/toplevel-aws-build.sh-new /path/to/just/a/little/disk/buildname

$ /path/to/just/a/little/disk/buildname/toplevel-aws-build.sh check
$ /path/to/just/a/little/disk/buildname/toplevel-aws-build.sh do
```

(Some waits still need to be implemented, so repeating "toplevel-aws-build.sh do" several
times may be necessary.)

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.
