#!/bin/bash

url=$vsphere_user:$vsphere_password@$vsphere_host

for i in $(govc find -k -u $url / -type m -runtime.powerState poweredOff -dc $vsphere_datacenter | grep -v " "); do
  if [ "$(govc vm.info -k -u $url -json $i | jq -r '.VirtualMachines[0].Config.ExtraConfig[] | select(.Key==("pxd.deployment")).Value' 2>/dev/null)" = TEMPLATE ] ; then
    echo Found template $i - please use this one, or delete it and retry.
    exit 1
  fi
done

echo This will take a few minutes...
cat <<EOF >/vsphere-rocky.json
{
  "variables": {
    "vsphere-server": "$vsphere_host",
    "vsphere-user": "$vsphere_user",
    "vsphere-password": "$vsphere_password",
    "vsphere-cluster": "$vsphere_compute_resource",
    "vsphere-datacenter": "$vsphere_datacenter",
    "vsphere-resource-pool": "$vsphere_resource_pool",
    "vsphere-network": "$vsphere_network",
    "vsphere-datastore": "$vsphere_datastore",
    "vsphere-folder": "$vsphere_template_dir",
    "vm-name": "$vsphere_template_base",
    "vm-cpu-num": "4",
    "vm-mem-size": "8192",
    "vm-disk-size": "52000",
    "iso_url": "https://dl.rockylinux.org/vault/rocky/8.7/isos/x86_64/Rocky-8.7-x86_64-minimal.iso",
    "kickstart_file": "/vsphere-ks.cfg"
  },
  "builders": [
    {
      "CPUs": "{{user \`vm-cpu-num\`}}",
      "RAM": "{{user \`vm-mem-size\`}}",
      "RAM_reserve_all": false,
      "boot_command": [
        "<wait>",
        "<tab>",
        "linux inst.ks=hd:/dev/sr1:vsphere-ks.cfg",
        "<enter>"
      ],
      "boot_order": "disk,cdrom",
      "boot_wait": "10s",
      "cluster": "{{user \`vsphere-cluster\`}}",
      "configuration_parameters": {
          "guestinfo.metadata": "---",
          "guestinfo.metadata.encoding": "---",
          "guestinfo.userdata": "---",
          "guestinfo.userdata.encoding": "---",
          "pxd.deployment": "TEMPLATE",
          "pxd.hostname": "---"
      },
      "convert_to_template": true,
      "datastore": "{{user \`vsphere-datastore\`}}",
      "disk_controller_type": "pvscsi",
      "folder": "{{user \`vsphere-folder\`}}",
      "guest_os_type": "rhel8_64Guest",
      "insecure_connection": "true",
      "iso_checksum": "sha256:13c3e7fca1fd32df61695584baafc14fa28d62816d0813116d23744f5394624b",
      "iso_url": "{{user \`iso_url\`}}",
      "cd_files": ["./vsphere-ks.cfg"],
      "cd_label": "kickstart",
      "network_adapters": [
        {
          "network": "{{user \`vsphere-network\`}}",
          "network_card": "vmxnet3"
        }
      ],
      "notes": "Build via Packer",
      "password": "{{user \`vsphere-password\`}}",
      "resource_pool": "{{user \`vsphere-resource-pool\`}}",
      "ssh_username": "root",
      "ssh_password": "portworx",
      "storage": [
        {
          "disk_size": "{{user \`vm-disk-size\`}}",
          "disk_thin_provisioned": true
        }
      ],
      "type": "vsphere-iso",
      "username": "{{user \`vsphere-user\`}}",
      "vcenter_server": "{{user \`vsphere-server\`}}",
      "vm_name": "{{user \`vm-name\`}}"
    }
  ],
  "provisioners": [
    {
      "inline": [
        "sudo dnf upgrade -y",
        "sudo dnf install -y cloud-init",
        "sudo dnf install -y epel-release",
        "sudo dnf install -y python3-devel",
        "sudo dnf install -y python3-pip",
        "sudo curl -sSL https://raw.githubusercontent.com/vmware/cloud-init-vmware-guestinfo/master/install.sh | sudo sh -"
      ],
      "type": "shell"
    }
  ]
}
EOF

cat <<\EOF >/vsphere-ks.cfg
repo --name=BaseOS --baseurl=https://download.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/
repo --name=AppStream --baseurl=https://download.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/
text
firstboot --enable
ignoredisk --only-use=sda
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
network  --bootproto=dhcp --device=link --onboot=true --noipv6
network  --hostname=localhost.localdomain
rootpw --iscrypted $6$oHCngZUb/uEBImIf$Og9pS/av0PCXBOd2saohkK0P8yFl72QG4ei3467bIaGFFfNxyoTW8KZevE6AhkXrDMgvbeOSchAS5c.NNaWLJ0
services --disabled="chronyd,avahi-daemon.service,bluetooth.service,rhnsd.service,rhsmcertd.service"
timezone UTC --isUtc --nontp
clearpart --all --initlabel
part /boot/efi --fstype=vfat --fsoptions='defaults,umask=0027,fmask=0077,uid=0,gid=0' --size=600 --ondisk=/dev/sda
part /boot --fstype=xfs --fsoptions='nosuid,nodev' --size=1024 --ondisk=/dev/sda
part / --fstype="xfs" --ondisk=sda --size=50000
bootloader --append="rd.driver.blacklist=dm-multipath,crashkernel=auto systemd.unified_cgroup_hierarchy=1" --location=mbr --boot-drive=sda

cdrom

%packages
@base
@core
kexec-tools

%end


%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

%post
dnf -y install open-vm-tools
systemctl enable vmtoolsd
systemctl start vmtoolsd
dnf -y install kernel-headers nfs-utils jq bash-completion nfs-utils chrony docker vim-enhanced git
dnf update -y glib2
%end

reboot --eject
EOF

cd /
/usr/bin/packer build /vsphere-rocky.json
