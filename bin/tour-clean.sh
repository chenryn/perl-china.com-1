#!/bin/sh
docker ps -a | grep '/run.sh /tmp' | awk '{print "docker rm "$1}' | bash
