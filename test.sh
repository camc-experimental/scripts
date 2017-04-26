#!/bin/bash

readarray parm < $1

device=$(echo $${parm[0]} | cut -f2 -d'=')
vg_name=$(echo $${parm[1]} | cut -f2 -d'=')
lv_name=$(echo $${parm[2]} | cut -f2 -d'=')
lv_args=$(echo $${parm[3]} | cut -f2 -d'=')
mount_point=$(echo $${parm[4]} | cut -f2 -d'=')
filesystem_type=$(echo $${parm[5]} | cut -f2 -d'=')

echo "device --> $device"
echo "vg_name --> $vg_name"
echo "lv_name --> $lv_name"
echo "lv_args --> $lv_args"
echo "mount_point --> $mount_point"
echo "filesystem_type --> $filesystem_type"

counter=1
retries=120

echo "check for distro"
if [ -f /etc/redhat-release ]; then
    echo "centos or rhel install lvm2"
    yum list lvm2
    until [[ $? -eq 0 ]] || ((counter > retries))
    do
        echo "checking for yum setup"
        ((counter++))
        sleep 2
        yum list lvm2
    done
    if ((counter > retries)); then
          echo "cannot locate lvm2 package from yum repo!"
        exit -1
    else
        yum install -y lvm2
        if [ $? -ne 0 ]; then
			echo "yum install of lvm2 failed"
			exit -2
		fi
    fi
fi

echo "check for disk"
counter=1
retries=20

until ((counter > retries)) || [[ -e "$device" ]]
do
    echo "looking for $device"
    ((counter++))
    sleep 2
done

if ((counter > retries)); then
    echo "$device cannot be found!"
    exit -1
else
    echo "$device found, proceed to pvcreate"
fi

echo "run pvcreate"
pvcreate $device

if [ $? -ne 0 ]; then
	echo "pvcreate failed"
	exit -2
fi

echo "run vgcreate"
vgcreate $vg_name $device
if [ $? -ne 0 ]; then
	echo "vgcreate failed"
	exit -3
fi

echo "run lvcreate"
lvcreate --name $lv_name $lv_args $vg_name
if [ $? -ne 0 ]; then
	echo "lvcreate failed"
	exit -4
fi

echo "run mkfs.$filesystem_type"
mkfs.$filesystem_type /dev/$vg_name/$lv_name
if [ $? -ne 0 ]; then
	echo "mkfs.$filesystem_type failed"
	exit -5
fi

echo "create $mount_point"
mkdir -p $mount_point
if [ $? -ne 0 ]; then
	echo "mkdir failed"
	exit -6
fi

echo "mount $mount_point"
mount /dev/$vg_name/$lv_name $mount_point
if [ $? -ne 0 ]; then
	echo "mount failed"
	exit -7
fi

echo "setup /etc/fstab"
echo "/dev/$vg_name/$lv_name $mount_point $filesystem_type defaults 0 0" >> /etc/fstab
if [ $? -ne 0 ]; then
	echo "failed to add entry to /etc/fstab"
	exit -8
fi

echo "filesystem $mount_point creates successfully"
