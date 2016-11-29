DEBUG=1
MOUNTPOINT=/mnt
if [ $DEBUG -eq 1 ]; then
  DEVNULL=""
else
  DEVNULL="> /dev/null 2>&1"
fi

