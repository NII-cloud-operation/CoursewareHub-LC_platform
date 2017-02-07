
## Build on KVM

These files must exist in the home directory:

```
~/ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshuser
~/ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.tar.gz
~/ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshkey
```

Then:
```
$ ./ind-steps/build-jh-environment/toplevel-kvm-build.sh-new /path/to/50Gig/of/disk/buildname

$ /path/to/50Gig/of/disk/buildname/toplevel-kvm-build.sh check
$ /path/to/50Gig/of/disk/buildname/toplevel-kvm-build.sh do
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
