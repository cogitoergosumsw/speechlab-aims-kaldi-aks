#!/bin/bash

# Fix encoding issues in oses with wromng LC_TYPE
export PYTHONIOENCODING=utf8

# schedule delete completed job
python3 /home/appuser/opt/cronjob.py & 

# start a local master
if [ "$ENABLE_HTTPS" == "true" ] ; then
    python3 /home/appuser/opt/kaldi-gstreamer-server/kaldigstserver/master_server.py --certfile=/home/appuser/opt/ssl/fullchain.cer  --keyfile=/home/appuser/opt/ssl/dev.aisingapore.org.key --port=8080 2>&1 | tee /home/appuser/opt/master.log
else 
    python3 /home/appuser/opt/kaldi-gstreamer-server/kaldigstserver/master_server.py 2>&1 | tee /home/appuser/opt/master.log
fi


