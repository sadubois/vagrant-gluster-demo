#!/bin/bash
# =====================================================================
#        File:  client_setup.sh
#     Project:  vagrant-gluster-demo
#    Location:  vagrant-gluster-demo/scripts/volume_setup.sh
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
# ssh rhgs-01 -n sudo /vagrant/scripts/gluster_setup.sh 

HOSTNAME=`hostname`
MODE=""
SCRIPTS=/vagrant

# --- SOURCE BASE ENVIRONMENT SETTINGS ---
. ${SCRIPTS}/environment.sh

#if [ "$1" != "_remove" -a "$1" != "FUSE" -a "$1" != "NFS3" ]; then
if [ "$1" == "" ]; then
  if [ ${HOSTNAME} != "rhgs-mgmt"  ]; then
    echo "ERROR: $0 required to run on rhgs-mgmt"; exit
  else
    echo "  Gluster Client Setup"
    echo "  Choose one of the following configuration options: "
    echo ""
    echo "  1.)  Native Client (glusterfs-fuse)"
    echo "  2.)  NFSv3"
    echo "  3.)  NFSv3 with CTDB"
    echo "  4.)  NFSv4 with NFS Ganewsha"
    echo "  5.)  SMB/CIFS"
    echo "  6.)  SMB/CIFS with CTDB"
    echo "  "
    echo "  9.)  Clean previous setup and devices "
    echo "  "
    while [ -z ${MODE} ]; do
      echo -e "  Select [1-2]: \c"; read x

      case "$x" in
        1) MODE="FUSE";;
        2) MODE="NFS3";;
        3) MODE="NFS3CTDB";;
        4) MODE="NFS4";;
        5) MODE="CIFS";;
        6) MODE="CIFSCTDB";;
        9) MODE="_remove";;
      esac
    done

    # --- CHECK FOR STORAGE SETUP ---
    stt=0
    for n in rhgs-01 rhgs-02 rhgs-03 rhgs-04; do
      ret=`ssh -q $n -n sudo [ ! -d /bricks/brick1 -a /bricks/brick2 ] && echo 1 || echo 0`
      if [ $ret -eq 1 ]; then
        echo "  ERROR; no gluster bricks are configured on node $n"; stt=1
      fi
    done

    if [ $stt -eq 1 ]; then
      echo "  ERROR; no gluster bricks are configured on all nodes, please run storage_setup.sh first"
      exit 0
    fi 

    # --- CHECK FOR VOLUME SETUP ---
    stt=`ssh -q rhgs-01 -n sudo /usr/sbin/gluster vol status gvol > /dev/null 2>&1; echo $?`
    if [ $stt -ne 0 ]; then
      echo "  ERROR; no gluster volumes are not yet configured, please run volume_setup.sh first"
      exit 0
    fi 

    if [ $MODE != "_remove" ]; then
      mountpoint -q $MOUNTPOINT; ret=$?
      if [ $ret -eq 0 ]; then sudo umount -f $MOUNTPOINT; fi
    fi

    if [ "$MODE" = "CIFS" ]; then
      mountpoint -q $MOUNTPOINT; ret=$?
      if [ $ret -eq 0 ]; then sudo umount -f $MOUNTPOINT; fi

      echo ""
      echo "  => Setting up CIFS/SMB Server (Samba) ---"
      for n in rhgs-01 rhgs-02 rhgs-03 rhgs-04; do
        ssh -q $n -n sudo ${SCRIPTS}/client_setup.sh CIFS
      done

      echo ""
      echo "  => Mounting Gluster Volume (gvol) ---"
      echo "     mount -t cifs "//rhgs-01/gluster-gvol" $MOUNTPOINT -o username=cifsuser,password=redhat"

      sudo mount -t cifs "//rhgs-01/gluster-gvol" $MOUNTPOINT -o username=cifsuser,password=redhat
    fi

    if [ "$MODE" = "NFS3" ]; then
      mountpoint -q $MOUNTPOINT; ret=$?
      if [ $ret -eq 0 ]; then sudo umount -f $MOUNTPOINT; fi

      echo ""
      echo "  => Setting up CIFS/SMB Server (Samba) ---"
      for n in rhgs-01 rhgs-02 rhgs-03 rhgs-04; do
        ssh -q $n -n sudo ${SCRIPTS}/client_setup.sh NFS3
      done

      echo ""
      echo "  => Mounting Gluster Volume (gvol) ---"
      echo "     mount -t nfs -o vers=3 rhgs-01:/gvol $MOUNTPOINT"

      sudo mount -t nfs -o vers=3 rhgs-01:/gvol $MOUNTPOINT
    fi

    if [ "$MODE" = "FUSE" ]; then
      mountpoint -q $MOUNTPOINT; ret=$?
      if [ $ret -eq 0 ]; then sudo umount -f $MOUNTPOINT; fi

      echo ""
      echo "  => Mounting Gluster Volume (gvol) ---"
      echo "     mount -t glusterfs rhgs-01:/gvol -o backupvolfile-server=rhgs-02,\\"
      echo "       backupvolfile-server=rhgs-03,backupvolfile-server=rhgs-04 /mnt"

      sudo mount -t glusterfs rhgs-01:/gvol -o backupvolfile-server=rhgs-02,backupvolfile-server=rhgs-03 $MOUNTPOINT
    fi
  fi 
fi

###########################################################################################
################################# EXECUTED ON STORAGE NODES ###############################
###########################################################################################

if [ "$1" == "CIFS" -o "$1" == "CIFSCTDB" ]; then
  # --- CREATE CIFS USER ---
  cnt=`grep -c cifsuser /etc/passwd`
  if [ $cnt -eq 0 ]; then 
    sudo useradd -s /sbin/nologin cifsuser
  fi

  echo -e "redhat\nredhat" | sudo /usr/bin/smbpasswd -a cifsuser > /dev/null 2>&1

  for n in 1 2 3 4; do
    sudo chown -R :cifsuser /bricks/brick${n}/
    sudo chmod 777 /bricks/brick${n}/
  done

  systemctl -q enable smb
  systemctl -q start smb

  #smbclient -L rhgs-01 -U cifsuser
  #smbclient "//rhgs-01/gluster-gvol" -N
  #mount -t cifs "//rhgs-01/gluster-gvol" /mnt -o username=cifsuser 
  #sudo mount -t cifs "//rhgs-01/gluster-gvol" /mnt -o username=cifsuser,password=redhat

  #yum provides /usr/sbin/mount.cifs

fi

if [ "$1" == "NFS3" -o "$1" == "NFS3CTDB" ]; then
echo "hostname:`hostname`"
  sudo gluster volume set gvol nfs.disable off
  #showmount -e rhgs-01
  #sudo gluster volume set gvol nfs.disable off
  #sudo gluster volume get gvol all
fi

# --- FUSE ---
if [ "$1" = "FUSE1" ]; then
  echo ""
  echo "  => Mounting Gluster Volume (gvol) ---"
  echo "     /usr/sbin/gluster volume create gvol \\"
  echo "       rhgs-01:${BR1} rhgs-01:${BR2} rhgs-01:${BR3} rhgs-01:${BR4} \\"
  echo "       rhgs-02:${BR1} rhgs-02:${BR2} rhgs-02:${BR3} rhgs-02:${BR4} \\"
  echo "       rhgs-03:${BR1} rhgs-03:${BR2} rhgs-03:${BR3} rhgs-03:${BR4} \\"
  echo "       rhgs-04:${BR1} rhgs-04:${BR2} rhgs-04:${BR3} rhgs-04:${BR4}"

  #eval /usr/sbin/gluster volume create gvol rhgs-01:${BR1} rhgs-01:${BR2} rhgs-01:${BR3} rhgs-01:${BR4} \
  #                                          rhgs-02:${BR1} rhgs-02:${BR2} rhgs-02:${BR3} rhgs-02:${BR4} \
  #                                          rhgs-03:${BR1} rhgs-03:${BR2} rhgs-03:${BR3} rhgs-03:${BR4} \
  #                                          rhgs-04:${BR1} rhgs-04:${BR2} rhgs-04:${BR3} rhgs-04:${BR4} $DEVNULL; ret=$?
#
#  if [ $ret -ne 0 ]; then
#    echo "ERROR: gluster volume create failed"; exit
#  fi
#
#  ret=1
#  while [ $ret -ne 0 ]; do
#    /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
#  done
#
#  echo "  => Setup of Distributed Volume (gvol) completed and volume started"
fi

if [ "$1" = "_remove" ]; then
  # --- CLEANUP GLUSTER VOLUMES ---
#  for vol in `sudo gluster volume list 2>/dev/null`; do
#    echo "y" | sudo gluster volume stop $vol force > /dev/nulls 2>&1
#    echo "y" | sudo gluster volume delete $vol > /dev/nulls 2>&1
#  done

#  sudo rm -rf /bricks/brick[1234]/*

  # --- REMOVE GLUSTER PEERS ---
#  for n in rhgs-02 rhgs-03 rhgs-04; do
#    sudo gluster peer detach $n > /dev/null 2>&1
#  done
  echo _remove
fi
