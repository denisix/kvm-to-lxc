# kvm-to-lxc
KVM to LXC converter script

### Usage:

1. select stopped KVM container name:
```$ virsh list --all
 Id   Name      State
--------------------------
 -    test34    shut off
```

2. use that VM name as an argument to the script:

`curl https://raw.githubusercontent.com/denisix/kvm-to-lxc/master/kvm-to-lxc.sh | sh test34`


3. script will do the rest:
- mount QCOW2 source container image
- create LXC container with the same **name** and using the same **OS** / **version**
- sync rootfs
- fix permissions, etc
- umount QCOW2
- start LXC (DONE)
