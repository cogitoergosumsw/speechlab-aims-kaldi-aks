#!/bin/bash

PORT=80

usage(){
  echo "Creates a worker and connects it to a master.";
  echo "Usage: $0 -y yaml_file";
}

while getopts "h?y:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    y)  YAML=$OPTARG
        ;;
    esac
done

#yaml file must be specified
if [ "$YAML" == "" ] ; then
  usage;
  exit 1;
fi;

#start worker and connect it to the master
export GST_PLUGIN_PATH=/opt/gst-kaldi-nnet2-online/src/:/opt/kaldi/src/gst-plugin/

python /opt/kaldi-gstreamer-server/kaldigstserver/worker.py -c $YAML -u ws://$MASTER:$PORT/worker/ws/speech
