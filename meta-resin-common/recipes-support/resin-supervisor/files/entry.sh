#!/bin/bash

#--- This script is now setup to fail if any environment variable is missing.

set -o errexit
set -o nounset

DOCKER_TIMEOUT=20 # Wait 20 seconds for docker to start

export PARTITION_SIZE=${PARTITION_SIZE:=1000}
export TARGET_REPOSITORY=${TARGET_REPOSITORY:=resin/i386-supervisor}
export TARGET_TAG=${TARGET_TAG:=master}

## Add code to check /export directories presence
#-- Create a blank disk image.
dd if=/dev/zero of=/export/data_disk.img bs=1M count=$PARTITION_SIZE
mkfs.btrfs /export/data_disk.img

# Setup the loop device with the disk image
mkdir /data_disk
mount -o loop /export/data_disk.img /data_disk

# Create the directory structures we use for Resin
mkdir -p /data_disk/docker
mkdir -p /data_disk/resin-data

# Start docker with the created image.
docker daemon -g /data_disk/docker -s btrfs &
echo "Waiting for docker to become ready.."
STARTTIME=$(date +%s)
ENDTIME=$(date +%s)
while [ ! -S /var/run/docker.sock ]
do
    if [ $(($ENDTIME - $STARTTIME)) -le $DOCKER_TIMEOUT ]; then
        sleep 1
        ENDTIME=$(date +%s)
    else
        echo "Timeout while waiting for docker to come up."
        exit 1
    fi
done

docker pull $TARGET_REPOSITORY:$TARGET_TAG
docker tag $TARGET_REPOSITORY:$TARGET_TAG $TARGET_REPOSITORY:latest

kill -TERM $(cat /var/run/docker.pid) && wait $(cat /var/run/docker.pid) && umount /data_disk

echo "Docker export successful."
