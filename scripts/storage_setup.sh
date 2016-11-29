#!/bin/bash
# =====================================================================
#        File:  storage_setup.sh
#     Project:  vagrant-gluster-demo
#    Location:  vagrant-gluster-demo/scripts/storage_setup.sh
#   Launguage:  bash / Shell
#    Category:  Storage
#     Purpose:  Setup Gluster Storage Configuration
#      Author:  Sacha Dubois
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# =====================================================================
# 08.08.2016  Sacha Dubois  new
# =====================================================================
# https://access.redhat.com/documentation/en-US/Red_Hat_Storage/3.1/html-single/Administration_Guide/index.html#chap-Red_Hat_Storage_Volumes-Creating_Dispersed_Volumes_1

HOSTNAME=`hostname`
MODE=""
SCRIPTS=/vagrant

# --- SOURCE BASE ENVIRONMENT SETTINGS ---
. ${SCRIPTS}/environment.sh

idx=0
for dsk in da db dc dd de; do
  [ -b /dev/s${dsk} ] && DSK=/dev/s${dsk} || DSK=/dev/v${dsk}
  if [ ! -b ${DSK}1 ]; then arr[$idx]=${DSK}; let idx=idx+1; fi
done

if [ "$1" != "_remove" -a "$1" != "_create_lvm" -a "$1" != "_create_dev" ]; then 
  if [ ${HOSTNAME} != "rhgs-mgmt"  ]; then 
    echo "ERROR: ä0 required so run on rhgs-mgmt"; exit 
  else
    # --- FIND DISK FORMAT sdX OR vdX ---
    #ret=`ssh -q rhgs-01 [ -b /dev/sdb ] && echo sdb || echo vdb`
    #if [ "${ret}" = "sdb" ]; then 
      SDB=sdb; SDC=sdc; SDD=sdd; SDE=sde
    #else
    #  SDB=vdb; SDC=vdc; SDD=vdd; SDE=vde
    #fi

    echo "  Gluster Storage Setup"
    echo "  Choose one of the following configuration options: "
    echo "  "
    echo "  1.)  Two bricks on $SDB and $SDC mounted as XFS"
    echo "       ${arr[0]} (100G) -> /bricks/brick1 (XFS)"
    echo "       ${arr[1]} (100G) -> /bricks/brick2 (XFS)"
    echo "       ${arr[2]} (100G) -> /bricks/brick3 (XFS)"
    echo "       ${arr[3]} (100G) -> /bricks/brick4 (XFS)"
    echo ""
    echo "  2.)  Two bricks on LVM Volumes (tin provisioned) based on $SDB, $SDC, $SDD and, $SDE"
    echo "       ${arr[0]} (100G) -> vg_bricks/brickspool (VG TinPool) -> brick1 (LV) -> /bricks/brick1 (XFS)"
    echo "       ${arr[1]} (100G) -> vg_bricks/brickspool (VG TinPool) -> brick2 (LV) -> /bricks/brick2 (XFS)"
    echo "       ${arr[2]} (100G) -> vg_bricks/brickspool (VG TinPool) -> brick3 (LV) -> /bricks/brick3 (XFS)"
    echo "       ${arr[3]} (100G) -> vg_bricks/brickspool (VG TinPool) -> brick4 (LV) -> /bricks/brick4 (XFS)"
    echo ""
    echo "  3.)  Clean previous setup and devices "
    echo "  "
    while [ -z ${MODE} ]; do
      echo -e "  Select [1,2]: \c"; read x
      if [ "$x" = "1" ]; then MODE="_create_dev"; fi
      if [ "$x" = "2" ]; then MODE="_create_lvm"; fi
      if [ "$x" = "3" ]; then MODE="_remove"; fi
    done
    
    for n in rhgs-01 rhgs-02 rhgs-03 rhgs-04 rhgs-05 rhgs-06; do
      cnt=`egrep -c "*. ${n}$" /etc/hosts`
      if [ $cnt -gt 0 ]; then
        ssh -q $n -n sudo ${SCRIPTS}/storage_setup.sh _remove 2>/dev/null
        ssh -q $n -n sudo ${SCRIPTS}/storage_setup.sh $MODE
      fi
    done
  fi
fi


if [ "$1" = "_create_dev" ]; then 
  mkfs.xfs -f -i size=512 ${arr[0]} > /dev/null 2>&1
  mkfs.xfs -f -i size=512 ${arr[1]} > /dev/null 2>&1
  mkfs.xfs -f -i size=512 ${arr[2]} > /dev/null 2>&1
  mkfs.xfs -f -i size=512 ${arr[3]} > /dev/null 2>&1

  mkdir -p /bricks/brick1
  mkdir -p /bricks/brick2
  mkdir -p /bricks/brick3
  mkdir -p /bricks/brick4

  echo "${arr[0]} /bricks/brick1 xfs rw,noatime,inode64,nouuid 1 2" >> /etc/fstab
  echo "${arr[1]} /bricks/brick2 xfs rw,noatime,inode64,nouuid 1 2" >> /etc/fstab
  echo "${arr[2]} /bricks/brick3 xfs rw,noatime,inode64,nouuid 1 2" >> /etc/fstab
  echo "${arr[3]} /bricks/brick4 xfs rw,noatime,inode64,nouuid 1 2" >> /etc/fstab

  mount /bricks/brick1 
  mount /bricks/brick2
  mount /bricks/brick3
  mount /bricks/brick4
fi

if [ "$1" = "_create_lvm" ]; then 
  echo "  => Configure Bricks on Storage Node ($HOSTNAME)"
  echo "     - Create Physical Volumes on /dev/sdb, /dev/sdc, /dev/sdd and /dev/sde"

  /usr/sbin/pvcreate ${arr[0]} ${arr[1]} ${arr[2]} ${arr[3]} -y > /dev/null 2>&1
  if [ $? -ne 0 ]; then echo "ERROR: Creating Physical Volumes failed"; exit 0; fi

  echo "     - Create Volumes Group (vg_bricks)"
  /usr/sbin/vgcreate vg_bricks ${arr[0]} ${arr[1]} ${arr[2]} ${arr[3]} > /dev/null 2>&1
  if [ $? -ne 0 ]; then echo "ERROR: Creating Volume Group (vg_bricks) failed"; exit 0; fi

  echo "     - Create thin provisioned Logical volume (brickspool)"
  /usr/sbin/lvcreate -l 100%FREE -T vg_bricks/brickspool > /dev/null 

  echo "     - Creating Logical volume (brick1, brick2, brick3 and brick4)"
  /usr/sbin/lvcreate -V 99G -T vg_bricks/brickspool -n brick1 > /dev/null 
  /usr/sbin/lvcreate -V 99G -T vg_bricks/brickspool -n brick2 > /dev/null 
  /usr/sbin/lvcreate -V 99G -T vg_bricks/brickspool -n brick3 > /dev/null 
  /usr/sbin/lvcreate -V 99G -T vg_bricks/brickspool -n brick4 > /dev/null 

  echo "     - Creating XFS Filesystem on (brick1, brick2, brick3 and brick4)"
  mkfs.xfs -i size=512 /dev/vg_bricks/brick1 > /dev/null 2>&1
  mkfs.xfs -i size=512 /dev/vg_bricks/brick2 > /dev/null 2>&1
  mkfs.xfs -i size=512 /dev/vg_bricks/brick3 > /dev/null 2>&1
  mkfs.xfs -i size=512 /dev/vg_bricks/brick4 > /dev/null 2>&1

  mkdir -p /bricks/brick1
  mkdir -p /bricks/brick2
  mkdir -p /bricks/brick3
  mkdir -p /bricks/brick4

  echo "/dev/vg_bricks/brick1 /bricks/brick1 xfs rw,noatime,inode64,nouuid 1 2"  >> /etc/fstab
  echo "/dev/vg_bricks/brick2 /bricks/brick2 xfs rw,noatime,inode64,nouuid 1 2"  >> /etc/fstab
  echo "/dev/vg_bricks/brick3 /bricks/brick3 xfs rw,noatime,inode64,nouuid 1 2"  >> /etc/fstab
  echo "/dev/vg_bricks/brick4 /bricks/brick4 xfs rw,noatime,inode64,nouuid 1 2"  >> /etc/fstab

  mount /bricks/brick1 
  mount /bricks/brick2
  mount /bricks/brick3
  mount /bricks/brick4
fi

if [ "$1" = "_remove" ]; then 
  # --- CLEANUP GLUSTER VOLUMES ---
  for vol in `sudo gluster volume list 2>/dev/null`; do
    echo "y" | sudo gluster volume stop $vol force > /dev/nulls 2>&1
    echo "y" | sudo gluster volume delete $vol > /dev/nulls 2>&1

    sudo rm -f /bricks/brick[12]/${vol}
  done

  # --- CLEANUP LOGICAL VOLUMES ---
  for n in brick1 brick2 brick3 brick4; do
    umount -f /bricks/$n > /dev/null 2>&1

    /usr/sbin/lvdisplay  /dev/vg_bricks/$n > /dev/null 2>&1; ret=$?
    if [ $ret -eq 0 ]; then 
       /usr/sbin/lvremove /dev/vg_bricks/$n -y > /dev/null 2>&1
    fi
  done

  vgdisplay vg_bricks > /dev/null 2>&1; ret=$?
  if [ $ret -eq 0 ]; then 
    /usr/sbin/vgremove vg_bricks -y > /dev/null 2>&1
  fi

  /usr/sbin/pvdisplay /dev/$SDB > /dev/null 2>&1; ret=$?

  # REMOVE FSTAB ENTRUES
  sed -i '/brick/d' /etc/fstab

  rmdir -f /bricks/brick1 /bricks/brick2 /bricks/brick3 /bricks/brick4 2>/dev/null
fi

