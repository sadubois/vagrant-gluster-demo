#!/bin/bash
# =====================================================================
#        File:  volume_setup.sh
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
CATHEGORY=""
SCRIPTS=/vagrant

# --- SOURCE BASE ENVIRONMENT SETTINGS ---
. ${SCRIPTS}/environment.sh

[ -b /dev/sdb ] && SDB=sdb || SDB=vdb
[ -b /dev/sdc ] && SDC=sdc || SDC=vdc

BR1=/bricks/brick1/gvol
BR2=/bricks/brick2/gvol
BR3=/bricks/brick3/gvol
BR4=/bricks/brick4/gvol
    
peer_nodes() {
  for n in 1 2 3 4 5 6; do
    cnt=`egrep -c "*.rhgs-0${n}$" /etc/hosts`
    if [ $cnt -gt 0 ]; then
      ssh -q rhgs-01 -n sudo /usr/sbin/gluster peer probe rhgs-0${n} > /dev/null 2>&1
    fi
  done
}

if [ "$1" == "" ]; then
  if [ ${HOSTNAME} != "rhgs-mgmt"  ]; then
    echo "ERROR: $0 required to run on rhgs-mgmt"; exit
  else
    clear
    echo "  Gluster Volume Setup"
    echo "  Choose one of the following configuration options: "
    echo ""
    echo "  1.)   Distributed Volumes"
    echo "  2.)   Striped Volumes"
    echo "  3.)   Dispersed Volumes"
    echo "  4.)   Replicated Volumes"
    echo "  5.)   Combined Volumes"
    echo "  6.)   Geo-Repication"
    echo ""
    echo "  9.)   Clean configuration and volumes"

    while [ -z ${CATHEGORY} ]; do
      echo -e "  Select [1-9]: \c"; read x

      case "$x" in
        1) CATHEGORY="DISTRIBUTED";;
        2) CATHEGORY="STRIPED";;
        3) CATHEGORY="DISPERSED";;
        4) CATHEGORY="REPLICATED";;
        5) CATHEGORY="COMBINED";;
        6) CATHEGORY="GEOREP";;
        9) MODE="_remove";;
      esac
    done

    if [ $CATHEGORY = "STRIPED" ]; then
      clear
      echo "  Gluster Volume Setup"
      echo "  Choose one of the following configuration options: "
      echo ""
      echo "       Striped Volumes"
      echo "  1.)   4 way Stripe on 4 Bricks "
      echo "  2.)   4 way Stripe on 16 Bricks "
      echo ""

      while [ -z ${MODE} ]; do
        echo -e "  Select [1-2]: \c"; read x

        case "$x" in
          1) MODE="${CATHEGORY}-4S4B";;
          2) MODE="${CATHEGORY}-4S16B";;
        esac
      done
    fi

    if [ $CATHEGORY = "DISTRIBUTED" ]; then
      clear
      echo "  Gluster Volume Setup"
      echo "  Choose one of the following configuration options: "
      echo ""
      echo "       Distributed Volumes"
      echo "  1.)   4 Bricks Distributed"
      echo "  2.)  16 Bricks Distributed"
      echo ""

      while [ -z ${MODE} ]; do
        echo -e "  Select [1-2]: \c"; read x

        case "$x" in
          1) MODE="${CATHEGORY}-4B";;
          2) MODE="${CATHEGORY}-16B";;
        esac
      done
    fi

    if [ $CATHEGORY = "DISPERSED" ]; then
      echo "  Gluster Volume Setup"
      echo "  Choose one of the following configuration options: "
      echo ""
      echo "       Dispersed Volumes"
      echo "  1.)  24 Brick Dispersed 4x(4+2)"
      echo "  2.)  22 Brick Dispersed 2x(8+3)"
      echo "  3.)  24 Brick Dispersed 2x(8+4)"
      echo ""

      while [ -z ${MODE} ]; do
        echo -e "  Select [1-3]: \c"; read x

        case "$x" in
          1) MODE="${CATHEGORY}-6B4+2D";;
          2) MODE="${CATHEGORY}-11B8+3D";;
          3) MODE="${CATHEGORY}-12B8+4D";;
        esac
      done
    fi

    if [ $CATHEGORY = "REPLICATED" ]; then
      echo "  Gluster Volume Setup"
      echo "  Choose one of the following configuration options: "
      echo ""
      echo "       Replicated Volumes"
      echo "  1.)  2-Way Repication Volume"
      echo "  2.)  4-Way Repication Volume"
      echo "  "

      while [ -z ${MODE} ]; do
        echo -e "  Select [1-2]: \c"; read x

        case "$x" in
          1) MODE="${CATHEGORY}-2WRVOL";;
          2) MODE="${CATHEGORY}-4WRVOL";;
        esac
      done
    fi

    if [ $CATHEGORY = "GEOREP" ]; then
      echo "  Gluster Volume Setup"
      echo "  Choose one of the following configuration options: "
      echo ""
      echo "       Geo-Replication"
      echo "  1.)  2-Way Repication Volume"
      echo ""

      while [ -z ${MODE} ]; do
        echo -e "  Select [1-3]: \c"; read x

        case "$x" in
          1) MODE="${CATHEGORY}-6B4+2D";;
          2) MODE="${CATHEGORY}-11B8+3D";;
          3) MODE="${CATHEGORY}-12B8+4D";;
        esac
      done
    fi

    while [ -z ${MODE} ]; do
      echo -e "  Select [1-9]: \c"; read x

      case "$x" in
        1) MODE="${CATHEGORY}-4BDVOL";;
        2) MODE="${CATHEGORY}-16BDVOL";;
        3) MODE="${CATHEGORY}-6B4+2D";;
        4) MODE="${CATHEGORY}-11B8+3D";;
        5) MODE="${CATHEGORY}-12B8+4D";;
        6) MODE="${CATHEGORY}-2WRVOL";;
        7) MODE="${CATHEGORY}-4WRVOL";;
        9) MODE="_remove";;
      esac
    done

    # --- CHECK FOR STORAGE SETUP ---
    stt=0
    for n in rhgs-01 rhgs-02 rhgs-03 rhgs-04 rhgs-05 rhgs-06; do
      cnt=`egrep -c "*. ${n}$" /etc/hosts`
      if [ $cnt -gt 0 ]; then
        ret=`ssh -q $n -n sudo [ ! -d /bricks/brick1 -a /bricks/brick2 ] && echo 1 || echo 0`
        if [ $ret -eq 1 ]; then
          echo "  ERROR; no gluster bricks are configured on node $n"; stt=1
        fi
      fi
    done

    if [ $stt -eq 1 ]; then
      echo "  ERROR; no gluster bricks are configured on all nodes, please run storage_setup.sh first"
      exit 0
    fi 

    # --- UNMOUNTING PREVIOUS VOLUMES ---
    mountpoint -q $MOUNTPOINT; ret=$?
    if [ $ret -eq 0 ]; then sudo umount -f $MOUNTPOINT; fi

    # --- REMOVING VOLUMES ---
    for n in rhgs-01 rhgs-02 rhgs-03 rhgs-04 rhgs-05 rhgs-06; do
      cnt=`egrep -c "*. ${n}$" /etc/hosts`
      if [ $cnt -gt 0 ]; then
        ssh -q $n -n sudo ${SCRIPTS}/volume_setup.sh _remove $DEVNULL
      fi
    done

    if [ $MODE != "_remove" ]; then
      # --- PEERING GLUSTER NODES ---
      peer_nodes

      # --- CREATING VOLUME ---
      ssh -q rhgs-01 -n sudo ${SCRIPTS}/volume_setup.sh $MODE

      # --- CREATING VOLUME ---
      ssh -q rhgs-01 -n sudo /sbin/gluster vol info gvol | sed -e 's/^/     /g' -e 1d
    fi
  fi 
fi

# -- 4 way stripe on 4 Bricks ---
if [ "$1" = "STRIPED-4S4B" ]; then
  echo ""
  echo "  => Creating 4 way Striped Volume (gvol) ---"
  echo "     /usr/sbin/gluster volume create gvol stripe 4 \\"
  echo "       rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1}"

  if [ $DEBUG -eq 1 ]; then
    /usr/sbin/gluster volume create gvol stripe 4 rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} 
  else
    /usr/sbin/gluster volume create gvol stripe 4 rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} > /dev/null
  fi

  if [ $? -ne 0 ]; then
    echo "ERROR: gluster volume create failed"; exit
  fi

  ret=1
  while [ $ret -ne 0 ]; do
    /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
  done

  echo "  => Setup of Striped Volume (gvol) completed and volume started"
fi

if [ "$1" = "REPLICATED-2WRVOL" ]; then
  echo ""
  echo "  => Creating 4 way Striped Volume (gvol) ---"
  echo "     /usr/sbin/gluster volume create gvol replica 2 \\"
  echo "       rhgs-01:${BR1} rhgs-03:${BR1}"

  if [ $DEBUG -eq 1 ]; then
    /usr/sbin/gluster volume create gvol replica 2 rhgs-01:${BR1} rhgs-03:${BR1} 
  else
    /usr/sbin/gluster volume create gvol replica 2 rhgs-01:${BR1} rhgs-03:${BR1} > /dev/null
  fi

  if [ $? -ne 0 ]; then
    echo "ERROR: gluster volume create failed"; exit
  fi

  ret=1
  while [ $ret -ne 0 ]; do
    /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
  done

  echo "  => Setup of Striped Volume (gvol) completed and volume started"
fi



# -- 4 way stripe on 16 Bricks ---
if [ "$1" = "STRIPED-4S16B" ]; then
  echo ""
  echo "  => Creating 4 way Striped Volume (gvol) ---"
  echo "     /usr/sbin/gluster volume create gvol stripe 4 \\"
  echo "       rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} \\"
  echo "       rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} \\"
  echo "       rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} \\"
  echo "       rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4}"

  if [ $DEBUG -eq 1 ]; then
    /usr/sbin/gluster volume create gvol stripe 4 rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} \
                                                  rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} \
                                                  rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} \
                                                  rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4}
  else
    /usr/sbin/gluster volume create gvol stripe 4 rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} \
                                                  rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} \
                                                  rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} \
                                                  rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4} > /dev/null 
  fi

  if [ $? -ne 0 ]; then
    echo "ERROR: gluster volume create failed"; exit
  fi

  ret=1
  while [ $ret -ne 0 ]; do
    /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
  done

  echo "  => Setup of Striped Volume (gvol) completed and volume started"
fi


# -- 16 Bricks Distributed ---
if [ "$1" = "DISTRIBUTED-16B" ]; then
  echo ""
  echo "  => Creating Distributed Volume (gvol) ---"
  echo "     /usr/sbin/gluster volume create gvol \\"
  echo "       rhgs-01:${BR1} rhgs-01:${BR2} rhgs-01:${BR3} rhgs-01:${BR4} \\"
  echo "       rhgs-02:${BR1} rhgs-02:${BR2} rhgs-02:${BR3} rhgs-02:${BR4} \\"
  echo "       rhgs-03:${BR1} rhgs-03:${BR2} rhgs-03:${BR3} rhgs-03:${BR4} \\"
  echo "       rhgs-04:${BR1} rhgs-04:${BR2} rhgs-04:${BR3} rhgs-04:${BR4}"

  if [ $DEBUG -eq 1 ]; then 
    /usr/sbin/gluster volume create gvol rhgs-01:${BR1} rhgs-01:${BR2} rhgs-01:${BR3} rhgs-01:${BR4} \
                                         rhgs-02:${BR1} rhgs-02:${BR2} rhgs-02:${BR3} rhgs-02:${BR4} \
                                         rhgs-03:${BR1} rhgs-03:${BR2} rhgs-03:${BR3} rhgs-03:${BR4} \
                                         rhgs-04:${BR1} rhgs-04:${BR2} rhgs-04:${BR3} rhgs-04:${BR4} 
  else
    /usr/sbin/gluster volume create gvol rhgs-01:${BR1} rhgs-01:${BR2} rhgs-01:${BR3} rhgs-01:${BR4} \
                                         rhgs-02:${BR1} rhgs-02:${BR2} rhgs-02:${BR3} rhgs-02:${BR4} \
                                         rhgs-03:${BR1} rhgs-03:${BR2} rhgs-03:${BR3} rhgs-03:${BR4} \
                                         rhgs-04:${BR1} rhgs-04:${BR2} rhgs-04:${BR3} rhgs-04:${BR4} > /dev/null 2>&1
  fi

  if [ $? -ne 0 ]; then
    echo "ERROR: gluster volume create failed"; exit
  fi

  ret=1
  while [ $ret -ne 0 ]; do
    /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
  done

  echo "  => Setup of Distributed Volume (gvol) completed and volume started"
fi

# -- 4 BRICKS DISTRIBUTED ---
if [ "$1" = "DISTRIBUTED-4B" ]; then
  echo ""
  echo "  => Creating 4 Brick Distributed Volume (gvol) ---"
  echo "     /usr/sbin/gluster volume create gvol \\"
  echo "       rhgs-01:${BR1} rhgs-02:${BR1} \\"
  echo "       rhgs-03:${BR1} rhgs-04:${BR1}"

  if [ $DEBUG -eq 1 ]; then 
    /usr/sbin/gluster volume create gvol rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} 
  else
    /usr/sbin/gluster volume create gvol rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} > /dev/null 2>&1
  fi

  if [ $? -ne 0 ]; then 
    echo "ERROR: gluster volume create failed"; exit
  fi 

  ret=1
  while [ $ret -ne 0 ]; do
    /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
  done

  echo "  => Setup of Distributed Volume (gvol) completed and volume started"
  echo ""
fi

# --- 6 BRICKS DISPERSED (4+2) ---
if [ "$1" = "DISPERSED-6B4+2D" ]; then
  cnt=`egrep -c "*. rhgs-06$" /etc/hosts`
  if [ $cnt -gt 0 ]; then
    echo ""
    echo "  => Creating 12 Bricks Dispersed (4+2) Volume (gvol) ---"
    echo "     /usr/sbin/gluster volume create gvol disperse-data 4 redundancy 2\\"
    echo "       rhgs-01:${BR1} rhgs-02:${BR1} \\"
    echo "       rhgs-03:${BR1} rhgs-04:${BR1} \\"
    echo "       rhgs-05:${BR1} rhgs-06:${BR1} \\"
    echo "       rhgs-01:${BR2} rhgs-02:${BR2} \\"
    echo "       rhgs-03:${BR2} rhgs-04:${BR2} \\"
    echo "       rhgs-05:${BR2} rhgs-06:${BR2} \\"
    echo "       rhgs-01:${BR3} rhgs-02:${BR3} \\"
    echo "       rhgs-03:${BR3} rhgs-04:${BR3} \\"
    echo "       rhgs-05:${BR3} rhgs-06:${BR3} \\"
    echo "       rhgs-01:${BR4} rhgs-02:${BR4} \\"
    echo "       rhgs-03:${BR4} rhgs-04:${BR4} \\"
    echo "       rhgs-05:${BR4} rhgs-06:${BR4} "
  
    if [ $DEBUG -eq 1 ]; then 
      /usr/sbin/gluster volume create gvol disperse-data 4 redundancy 2 \
      rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} rhgs-05:${BR1} rhgs-06:${BR1} \
      rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} rhgs-05:${BR2} rhgs-06:${BR2} \
      rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} rhgs-05:${BR3} rhgs-06:${BR3} \
      rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4} rhgs-05:${BR4} rhgs-06:${BR4} 
    else
      /usr/sbin/gluster volume create gvol disperse-data 4 redundancy 2 \
      rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} rhgs-05:${BR1} rhgs-06:${BR1} \
      rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} rhgs-05:${BR2} rhgs-06:${BR2} \
      rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} rhgs-05:${BR3} rhgs-06:${BR3} \
      rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4} rhgs-05:${BR4} rhgs-06:${BR4} $DEVNULL
    fi

    if [ $? -ne 0 ]; then
      echo "ERROR: gluster volume create failed"; exit
    fi

    ret=1
    while [ $ret -ne 0 ]; do
      /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
    done
  
    echo "  => Setup of Dispersed Volume (gvol) completed and volume started"
  
  else
    echo ""
    echo "  WARNING: Dispersed volumes need at least to have build on 6 different nodes"
    echo "           to qurantee redundancy by loosing one ore multiple bricks"
    echo "           Creating of dispersed volume aborted"
    echo ""
    exit
  fi
fi

# --- 11 BRICKS DISPERSED (8+3) ---
if [ "$1" = "DISPERSED-11B8+3D" ]; then
echo gaga2
  cnt=`egrep -c "*. rhgs-06$" /etc/hosts`
  if [ $cnt -gt 0 ]; then
    echo ""
    echo "  => Creating Dispersed (8+3) Volume (gvol) ---"
    echo "     /usr/sbin/gluster volume create gvol disperse-data 8 redundancy 3\\"
    echo "       rhgs-01:${BR1} rhgs-02:${BR1} \\"
    echo "       rhgs-03:${BR1} rhgs-04:${BR1} \\"
    echo "       rhgs-05:${BR1} rhgs-06:${BR1} \\"
    echo "       rhgs-01:${BR2} rhgs-02:${BR2} \\"
    echo "       rhgs-03:${BR2} rhgs-04:${BR2} \\"
    echo "       rhgs-05:${BR2} rhgs-06:${BR2} \\"
    echo "       rhgs-01:${BR3} rhgs-02:${BR3} \\"
    echo "       rhgs-03:${BR3} rhgs-04:${BR3} \\"
    echo "       rhgs-05:${BR3} rhgs-06:${BR3} \\"
    echo "       rhgs-01:${BR4} rhgs-02:${BR4} \\"
    echo "       rhgs-03:${BR4} rhgs-04:${BR4} \\"
    echo "       rhgs-05:${BR4} rhgs-06:${BR4} "

    if [ $DEBUG -eq 1 ]; then
      /usr/sbin/gluster volume create gvol disperse-data 8 redundancy 3 \
      rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} rhgs-05:${BR1} rhgs-06:${BR1} \
      rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} rhgs-05:${BR2}  \
      rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} rhgs-05:${BR3} rhgs-06:${BR3} \
      rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4} rhgs-05:${BR4} force
    else
      /usr/sbin/gluster volume create gvol disperse-data 8 redundancy 3 \
      rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} rhgs-05:${BR1} rhgs-06:${BR1} \
      rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} rhgs-05:${BR2}  \
      rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} rhgs-05:${BR3} rhgs-06:${BR3} \
      rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4} rhgs-05:${BR4} force $DEVNULL
    fi

    if [ $? -ne 0 ]; then
      echo "ERROR: gluster volume create failed"; exit
    fi

    ret=1
    while [ $ret -ne 0 ]; do
      /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
    done

    echo "  => Setup of Dispersed Volume (gvol) completed and volume started"
    echo ""
    echo "  WARNING: Dispersed volumes in a (8+3) configuration requires to be build"
    echo "           on 11 different gluster nodes to qurantee redundancy by loosing "
    echo "           one ore multiple bricks. This esample was build with he 'force' option"
    echo ""
  else
    echo ""
    echo "  WARNING: Dispersed volumes need at least to have build on 6 different nodes"
    echo "           to qurantee redundancy by loosing one ore multiple bricks"
    echo "           Creating of dispersed volume aborted"
    echo ""
    exit
  fi
fi

# --- 12 BRICKS DISPERSED (8+4) ---
if [ "$1" = "DISPERSED-12B8+4D" ]; then
echo gaga1
  cnt=`egrep -c "*. rhgs-06$" /etc/hosts`
  if [ $cnt -gt 0 ]; then
    echo ""
    echo "  => Creating Dispersed (8+4) Volume (gvol) ---"
    echo "     /usr/sbin/gluster volume create gvol disperse-data 8 redundancy 4\\"
    echo "       rhgs-01:${BR1} rhgs-02:${BR1} \\"
    echo "       rhgs-03:${BR1} rhgs-04:${BR1} \\"
    echo "       rhgs-05:${BR1} rhgs-06:${BR1} \\"
    echo "       rhgs-01:${BR2} rhgs-02:${BR2} \\"
    echo "       rhgs-03:${BR2} rhgs-04:${BR2} \\"
    echo "       rhgs-05:${BR2} rhgs-06:${BR2} \\"
    echo "       rhgs-01:${BR3} rhgs-02:${BR3} \\"
    echo "       rhgs-03:${BR3} rhgs-04:${BR3} \\"
    echo "       rhgs-05:${BR3} rhgs-06:${BR3} \\"
    echo "       rhgs-01:${BR4} rhgs-02:${BR4} \\"
    echo "       rhgs-03:${BR4} rhgs-04:${BR4} \\"
    echo "       rhgs-05:${BR4} rhgs-06:${BR4} "

    if [ $DEBUG -eq 1 ]; then
      /usr/sbin/gluster volume create gvol disperse-data 8 redundancy 4 \
      rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} rhgs-05:${BR1} rhgs-06:${BR1} \
      rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} rhgs-05:${BR2} rhgs-06:${BR2} \
      rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} rhgs-05:${BR3} rhgs-06:${BR3} \
      rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4} rhgs-05:${BR4} rhgs-06:${BR4} force
    else
      /usr/sbin/gluster volume create gvol disperse-data 8 redundancy 4 \
      rhgs-01:${BR1} rhgs-02:${BR1} rhgs-03:${BR1} rhgs-04:${BR1} rhgs-05:${BR1} rhgs-06:${BR1} \
      rhgs-01:${BR2} rhgs-02:${BR2} rhgs-03:${BR2} rhgs-04:${BR2} rhgs-05:${BR2} rhgs-06:${BR2} \
      rhgs-01:${BR3} rhgs-02:${BR3} rhgs-03:${BR3} rhgs-04:${BR3} rhgs-05:${BR3} rhgs-06:${BR3} \
      rhgs-01:${BR4} rhgs-02:${BR4} rhgs-03:${BR4} rhgs-04:${BR4} rhgs-05:${BR4} rhgs-06:${BR4} force $DEVNULL
    fi

    if [ $ret -ne 0 ]; then
      echo "ERROR: gluster volume create failed"; exit
    fi

    ret=1
    while [ $ret -ne 0 ]; do
      /usr/sbin/gluster volume start gvol > /dev/null 2>&1; ret=$?
    done

    echo "  => Setup of Dispersed Volume (gvol) completed and volume started"
    echo ""
    echo "  WARNING: Dispersed volumes in a (8+3) configuration requires to be build"
    echo "           on 11 different gluster nodes to qurantee redundancy by loosing "
    echo "           one ore multiple bricks. This esample was build with he 'force' option"
    echo ""
  else
    echo ""
    echo "  WARNING: Dispersed volumes need at least to have build on 6 different nodes"
    echo "           to qurantee redundancy by loosing one ore multiple bricks"
    echo "           Creating of dispersed volume aborted"
    echo ""
    exit
  fi
fi



if [ "$1" = "_remove" ]; then
  # --- CLEANUP GLUSTER VOLUMES ---
  for vol in `sudo gluster volume list 2>/dev/null`; do
    echo "y" | sudo gluster volume stop $vol force > /dev/nulls 2>&1
    echo "y" | sudo gluster volume delete $vol > /dev/nulls 2>&1
  done

  sudo rm -rf /bricks/brick[1234]/*

  # --- REMOVE GLUSTER PEERS ---
  for n in rhgs-02 rhgs-03 rhgs-04; do
    sudo gluster peer detach $n > /dev/null 2>&1
  done
fi
