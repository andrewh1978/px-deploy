#!/bin/bash

pxctl volume create objectstorevol --size 10
pxctl objectstore create -v objectstorevol
pxctl objectstore enable
while ! pxctl objectstore status | grep -q Running ; do echo Waiting for objectstore; sleep 1; done
echo Execute this command to add objectstore credentials to Portworx:
pxctl objectstore status | tail -5 | sed 's/9010 .*/9010 minio/'
