#!/bin/bash

# MASTER="localhost"
# PORT=80

# usage(){
#   echo "Usage: $0";
# }

export PYTHONIOENCODING=utf8

# schedule delete completed job
python3 /home/appuser/opt/cronjob.py & 

if [ "$MASTER" == "localhost" ] ; then
  # start a local master
  python3 /home/appuser/opt/kaldi-gstreamer-server/kaldigstserver/master_server.py 2>&1 | tee /home/appuser/opt/master.log
fi

exec "$@"

