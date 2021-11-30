# NUCtrays
This is a very poorly documented set of tools and code I've used to create a small k8s cluster using NUC devices.

Eventually I'll clean my docs up.

You'll find the necessary bits to bootstrap the cluster in `ansible` and the stuff I'm running on top of the cluster in `tanka`

# Creating the initial image

Install Ubuntu onto the SD card of one of the NUCs, configuring the following;

* A default user (`ryan` in my case)
* A trusted ssh public key in `/home/ryan/.ssh/authorized_keys` (used by ansible to connect via ssh)
* A password for the user
* A default static IP (`192.168.1.14` in my case)

# Duping the SD Cards

https://jaimyn.com.au/the-fastest-way-to-clone-sd-card-macos/

`sudo diskutil unmountDisk /dev/disk2`

`sudo gdd of=/dev/disk2 if=nuc-ubuntu20.04-LTS.dmg status=progress bs=16M`

# Changing the identity of each device from above base image

`ansible_host` for all devices should be the interim IP at first (for me `192.168.1.14`). It'll look like this.

```
all:
  hosts:
  children:
    petnodes:
      hosts:
        18N1L:
          ansible_host: 192.168.1.14
          ip: 192.168.1.244/24
        18N1R:
          ansible_host: 192.168.1.14
          ip: 192.168.1.245/24
        18N2L:
          ansible_host: 192.168.1.14
          ip: 192.168.1.246/24
        18N2R:
          ansible_host: 192.168.1.14
          ip: 192.168.1.247/24
```

Power on only one device with the interim IP at any given time. Change the identity thusly.

`ansible-playbook -e '{"reboot": "true", "replace_keys": "true"}' -i inventory -u ryan -K changeidentity.yaml -l <name of unit>`

## ProTip: Remove variable from -e, don't set it to false, since the check is if the variable is set, not what it is set to.

It will prompt for a sudo password, then re-ID the host. At that point you can change `ansible_host` to match the IP for any possible future applications.

# Gluster config

`ansible glusterd -a "wipefs -af /dev/sda" -Kb -u ryan -i inventory`

Had to reboot after above.

`ansible-playbook -i inventory/nucs.yaml -u ryan -K -b glusterheketi.yaml -l glusterd`

# BGP

https://typhoon.psdn.io/topics/hardware/
https://docs.ansible.com/ansible/latest/collections/community/network/edgeos_config_module.html

## Ansible
TODO

* Don't forget to grab submodules

Create a docker image that includes what I need, and can be executed like `docker run --rm -it -v $(pwd):/an -v ~/.ssh:/root/.ssh --entrypoint sh willhallonline/ansible`

Needs;
`ansible-galaxy collection install community.general`
`ansible-galaxy collection install community.crypto`
`ansible-galaxy collection install ansible.posix`
`ansible-galaxy install geerlingguy.nfs`
`ansible-galaxy collection install ansible.netcommon`
`pip install netaddr`