![wasted.io](http://wasted.io/images/soon/wasted.png)

=======

### We do allow pull requests, but please follow the [contribution guidelines](https://github.com/wasted/ezhyve/blob/master/CONTRIBUTING.md).

### What's this?

bhyve is the native FreeBSD Hypervisor (similar to xen, Linux KVM) which was introduced in FreeBSD 10. ezhyve's goal is easier creation of bhyve VMs. Currently a rc script and a startall feature are missing but its on the [TODO](https://github.com/wasted/ezhyve/blob/master/TODO) list. Check it out for things ezhyve might **not** do for you yet.

ezhyve was inspired by [erdgeist's](https://twitter.com/erdgeist) [sysutils/ezjail](http://erdgeist.org/arts/software/ezjail/) and is based on [Michael Dexters](https://twitter.com/michaeldexter) [bhyve-tools](http://bhyve.org/tools/).

### How to start
- edit etc/ezhyve/ezhyve.conf to **your** needs! (PATHs)
- you may also have to change the path to functions.sh and ezhyve.conf in bin/ezhyve.sh.

### What features are currenly implementet
* per vm configs (created via ezhyve.sh)
* template support to make it easier to add new FreeBSD releases / Linux Distributions
* ezhyve supports a couple of commands:

### Usage
```
ezhyve.sh create vmname - create a config for an vm
ezhyve.sh start vmname - start vmname from image
ezhyve.sh stop vmname - stop / destroys vm
ezhyve.sh cdboot vmname - boots from iso file
ezhyve.sh provision vmname - provision an FreeBSD VM
ezhyve.sh delete vmname - deletes VM dir and config file
ezhyve.sh list - lists running vms
ezhyve.sh console vmname - connect to console of vmname
ezhyve.sh debug - TODO
ezhyve.sh grub vmname - grub
```

### Options

```
ezhyve.sh create [-t FreeBSD (Linux, OpenBSD)] [-v 9.2-RELEASE (debian...)] [-m 1024 (RAM in MB)] [-d 2G (Disksize in GB)] [-p 1 (Num of. CPUs)] [-c default (console type)] [-l mbr (gpt)] [-o ahci-hd (virtio-blk)] [-D /dev/foo (e.g. zvol/zroot/vm0)] [-i /path/to/img.iso] vmname
```

### cdboot from iso
**this feature (-i) needs some more love!!**

```
ezhyve.sh cdboot [-i /path/to/img.iso] vmname
```

### What templates are available?

```
[root ~/wasted.io/ezhyve]# ls -R1 etc/ezhyve/vmtemplate/*
== FreeBSD ==
etc/ezhyve/vmtemplate/FreeBSD:
10.0-RC4
10.0-RC5
10.0-RELEASE
11.0-CURRENT
9.1-RELEASE
9.2-RELEASE
9.2-STABLE

== Linux ==
etc/ezhyve/vmtemplate/Linux:
archlinux231201
centos6.5
debian7.3.0
dsl4.4.9
rhel7beta
slackware14.1
ubuntu13.04
ubuntu13.10

== OpenBSD ==
etc/ezhyve/vmtemplate/OpenBSD:
5.4

== pfSense ==
etc/ezhyve/vmtemplate/pfSense:
2.1
```

For -t use the directory names beneath etc/ezhyve/vmtemplate (FreeBSD, Linux ...).

For -v use the filename (without the .conf) in etc/ezhyve/vmtemplate/$EZHYVE_VM_TYPE/.

To create your own template just check out etc/ezhyve/vmtemplate.

### RAM size, Disk size, cpu num ...

The following examples will create a VM config with default settings:

```
: ${EZHYVE_RAMSIZE=512} # in MB
: ${EZHYVE_DISKSIZE="2G"} # in GB
: ${EZHYVE_CPUNUM=1} # INT
```

To change these defaults see ezhyve.conf, but you can also create a VM config like this:

```
ezhyve.sh create -m 1024 -d 5G -p 2 VMname
```

This would give the VM 1024MB ram, an 5G image would be created with 2 cpus.

**Just call ezhyve.sh create for usage.**


### Creating a FreeBSD VM

```
# creating the vm template
ezhyve.sh create vmname
# -t FreeBSD supports cdboot and provisioning ... only one at a time makes sense ;)
ezhyve.sh provision vmname
ezhyve.sh cdboot vmname
# adjust FBSD_DISTFILES in ezhyve.conf; defaults to base.txz and kernel.txz
# if you dont have the iso yet you can fetch it
ezhyve.sh fetch vmname
# start the vm
ezhyve.sh start vmname
# connect to console if EZHYVE_CONSOLE is nmdm, lpc, tmux
ezhyve.sh console vmname

ezhyve.sh create VMfreebsd10 # this would create a FreeBSD 10.0-RELEASE vm config
ezhyve.sh create -t FreeBSD -v 9.2-RELEASE VMfreebsd # this would create a FreBSD 9.2-RELEASE VM
```

### Creating a Linux VM

```
Here you have to ALWAYS specify -t and -v
# creating the vm template
ezhyve.sh create -t Linux -v ubuntu13.10 vmname
# only cdboot is supported for installation
ezhyve.sh cdboot vmname
# if you dont have the iso you can fetch it before cdboot
ezhyve.sh fetch vmname
# you may have to stop the Linux VM after installation is finished
ezhyve.sh stop vmname
# start the vm
ezhyve.sh start vmname
# connect to console if EZHYVE_CONSOLE is nmdm, lpc, tmux
ezhyve.sh console vmname
```

### Provision a FreeBSD VM

See fbsdprovision() in functions.sh ... it's on the TODO list to make this more customizable

```
dhcp
empty root pw
PermitRootLogin yes
/etc/rc.conf created
/etc/fstab created
/etc/ttys edited
```

### Stopping a VM

```
ezhyve.sh stop vmname
```

### Deleting the VM config and the VM directory (device.map, image)

```
ezhyve.sh delete vmname
```

### Linux VMs still make kinda trouble ...

I had some luck booting an [Ubuntu](http://www.ubuntu.com) and an [Debian](http://www.debian.org) but not so much with the other ones.

I got a lot of black consoles with no response so if you want to see the commands grub-bhyve tried to execute have a look at

```
$PATH_BHYVEVMS/$EZHYVE_VM_NAME/GRUBBOOTCMD
$PATH_BHYVEVMS/$EZHYVE_VM_NAME/GRUBISOCMD
```

### Using an existing Image

Create an VM config via
```
ezhyve.sh create vmname
```
and instead of provisioning or cdboot to install it just copy your existing image file (and device.map) to $PATH_BHYVEVMS/$EZHYVE_VM_NAME/$EZHYVE_VM_NAME.img

Now all you need to do is
```
ezhyve.sh start vmname
```
## Legal

```
FreeBSD is a registered trademark of the FreeBSD Foundation. 
```


## License

```
  Copyright 2012, 2013, 2014 wasted.io Ltd <really@wasted.io>

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
```

