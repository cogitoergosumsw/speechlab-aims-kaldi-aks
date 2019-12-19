#!/bin/bash

echo "start_worker.sh: MASTER=$MASTER, MODEL_DIR=$MODEL_DIR RUN_FREQ=$RUN_FREQ"

#start worker and connect it to the master
export GST_PLUGIN_PATH=/home/appuser/opt/gst-kaldi-nnet2-online/src/:/home/appuser/opt/kaldi/src/gst-plugin/
# Fix encoding issues in oses with wromng LC_TYPE
export PYTHONIOENCODING=utf8

# -o ro  mean read-only https://github.com/Azure/azure-storage-fuse/issues/79
mkdir -p /home/appuser/opt/models & \
 sudo -E blobfuse /home/appuser/opt/models --container-name=$AZURE_CONTAINER --tmp-path=/mnt/blobfusetmp --file-cache-timeout-in-seconds=315360000 -o ro -o allow_other

# automatically use engine template file if the model does not have engine.yaml file
FILE=/home/appuser/opt/models/$MODEL_DIR/engine.yaml
if test -f "$FILE"; then
    echo "$FILE exist"
    export USE_WHICH_ENGINE_FILE=$FILE
else 
    echo "$FILE does not exist, use engine template"
    sed -i 's/{{MODEL_DIR}}/'"$MODEL_DIR"'/g' /home/appuser/opt/engine_template.yaml
    export USE_WHICH_ENGINE_FILE=/home/appuser/opt/engine_template.yaml
fi

echo "decided to use engine file: $USE_WHICH_ENGINE_FILE"

python /home/appuser/opt/kaldi-gstreamer-server/kaldigstserver/worker.py -c $USE_WHICH_ENGINE_FILE -u ws://$MASTER/worker/ws/speech 2>&1 | tee /home/appuser/opt/worker.log 