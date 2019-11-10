#!/bin/bash

MASTER="localhost"
PORT=80

usage(){
  echo "Usage: $0";
}


if [ "$MASTER" == "localhost" ] ; then
  # start a local master
  python /opt/kaldi-gstreamer-server/kaldigstserver/master_server.py --port=$PORT
fi

exec "$@"

