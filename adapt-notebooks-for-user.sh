#!/bin/bash
original_notebooks="/srv/nii-project-2016/notebooks"

username="$1"
udir="/home/$username"

mkdir -p "$udir"/.ssh
chmod 700 "$udir"/.ssh
cat >"$udir"/.ssh/config <<EEE
Host *
  StrictHostKeyChecking no
  TCPKeepAlive yes
  UserKnownHostsFile /dev/null
  ForwardAgent yes
EEE
chmod 600 "$udir"/.ssh/config

cat >"$udir/.musselrc" <<EEE
DCMGR_HOST=192.168.11.90
account_id=a-shpoolxx
EEE

	    cat <<'EOS' > "$udir"/mykeypair
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA6KmXs11l/2WUIBDYmTB0T+BXwwCXT+RP/CTVtxq1Tnq8biwa
pDxHuYgvQWSOOH7DIZq/+GU+P69BBWAbnd1LNkWDOoMmnaIthXQBptZupYFfYiKA
Uh4UH0L0wwenifE2yV+SdWLT6FEiiQ2RTatqK1xiWSwvduWkeMA+dW1NbSk0XmEh
Z76QLsRxrs9JF4jqPXJVulzgjnD9Z5tkNY7MyfD1PNJcM2+MS8XmAApxLQLrfxEl
LZMsgvzvFVec45siOiG+VTWbGADc3lBSHIj2pt6aZDLkOhSnZegmsciVFQk1ulLF
jGjD2LoqYT5/UirpwQsElsjWTEEbBZzV10AVlwIDAQABAoIBAQCdnQ4cv1/ypXC0
TFU/abjRx8wMWWEoCSY6TQXOtjQvByyRgiVGL2PzhxNkPGewVAeCw1/bOVLzN5lX
t+Tdi+WAzZR51hEZ5pzp9E2OJWPtkPf59h9yAdhl2SkQ2iWgaB1STAFermWZ0yUP
LXbK5B3XZA1oFWvOIwHJn4pwaGx0TpOtEjPHiEkJxj1SRAzN377Uu3SNz9UsRrfQ
3v7iLxrPvwqhXIBo1VzQIliWzH5/IQ6xAqAsMLTo0uJ+d1wkoZ6nGkjt+LYD5hyD
Ov76lOjlevkPu3BENwwt3Este2d00gOC2Qt649P/chd9B8vc4ZZ8F3bPVfmfdiJt
fYRPaF5ZAoGBAP5vEA/lWH5xN6dB7j+wFPLAP7+8H2jz4aBcDWCiDjoMA4JRvc8V
gJxaW33b8gbP39byZAfBLNWHPE+4q/95CW7TkXnzdCR9HxeKC77jnBXg6wX5zist
E/cDMPykATtMqUFf/K46lPjaUbn4gmLEkc9lS7V+ySoPMdMUG6zqQf2DAoGBAOoY
OPSHu2Y7R4V3BnzNeGz6PCrohz7IjqjSD74KhAhuFCM7w+ymDmk2xSIR4S4F7qlD
mBodXpncqxQMtkF2pRRGDefbTXW5m+lWOy/DrsYV0bqy5OqA2r7Ukj5M0o97S8D1
vhTxwXCehx8GX8RlbybuMkfpB2NefMxakG+BAX9dAoGASPS/vk8dGOSN+L/G+Swc
VZ8aqHfg6c9Emx7KFzNgsPRQ7UVTD9YykqK2KViwBZQFszS9yhtyJ6gnexSQ/ShP
tB+mTzmny+60w6Mpywqo7v0XZxdCLs82MlYP7eF5GO/aeIx1f9/8Z37ygEjp2jhT
NwzssJYySIUi3Eufw+1IDtECgYEAr3NOJMAiTWH6neZyn1Fkg9EdDU/QJdctTQx7
rgS1ppfSUgH2O0TOIj9hisJ50gOyN3yo4FHI2GrScimA5BmnakWDIJZ2PNjLKRxv
KcJxGJe75EE2XygKSuKJZVYwrkdLpKjKOWpkgCLgxPkDB/C6WSRH3SujVO+5e3QZ
MukulSUCgYBMtuQ6VMrlMTedLW6ryd8VYsVNZaAGuphejFCCuur13M/1wHrRUzqM
hECAngl6fus+weYMiQYx1V8oxz3tBdYO8KKG8pnQySTt5Dln19+vqH2+18RWDKtH
0rwxRJ4Rc3wKFVwK+gz6NsBvftnQAK52qWip71tPY7zt9LeWWJv08g==
-----END RSA PRIVATE KEY-----
EOS
	    chmod 600 "$udir"/mykeypair

	    cat <<'EOS' > "$udir"/mykeypair.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDoqZezXWX/ZZQgENiZMHRP4FfDAJdP5E/8JNW3GrVOerxuLBqkPEe5iC9BZI44fsMhmr/4ZT4/r0EFYBud3Us2RYM6gyadoi2FdAGm1m6lgV9iIoBSHhQfQvTDB6eJ8TbJX5J1YtPoUSKJDZFNq2orXGJZLC925aR4wD51bU1tKTReYSFnvpAuxHGuz0kXiOo9clW6XOCOcP1nm2Q1jszJ8PU80lwzb4xLxeYACnEtAut/ESUtkyyC/O8VV5zjmyI6Ib5VNZsYANzeUFIciPam3ppkMuQ6FKdl6CaxyJUVCTW6UsWMaMPYuiphPn9SKunBCwSWyNZMQRsFnNXXQBWX knoppix@Microknoppix
EOS

shopt -s dotglob
if ! [ -s "$udir/notebooks" ]; then
    cp -a "$original_notebooks"/* "$udir"
    find "$udir" -type f -exec sed -i -e "s,/home/centos,/home/$username,g" {} \;
    find "$udir" -type f -exec sed -i -e "s,\.\./mykeypair,/home/$username/mykeypair,g" {} \;
    find "$udir" -type f -exec sed -i -e "s,sudo ip -s,# sudo ip -s,g" {} \;
    chown -R "$username:$username" "$udir"
fi

[ -s "$udir/notebooks" ] || ln -s "$udir" "$udir/notebooks"
