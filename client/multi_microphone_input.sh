#!/usr/bin/env bash

BASE_COMMAND="python client_2_ssl_sw.py -o stream -u wss://speechlab-online.dev.aisingapore.org/client/ws/speech -r 32000 -t abc -m "

usage() { 
    cat << EOF

Upload Multiple Audio Files for decoding
----------------------------------------------------------------------------------------------------------------------------------------
Usage: $0 [input audio file names in succession with a whitespace between e.g audio/episode1.wav audio/episode2.wav]
----------------------------------------------------------------------------------------------------------------------------------------

EOF
    1>&2
    exit 2
}

# if [ $# -eq 0 ]; then
#     usage
# fi

MODEL='SingaporeCS_0519NNET3 &'
SLEEP_TIME=0

for i in {1..20};
do
    if [ $i -gt 10 ]; then
        MODEL="SingaporeMandarin_0519NNET3 &"
    fi
    CLIENT_COMMAND="${BASE_COMMAND} ${MODEL}"
    eval $CLIENT_COMMAND
    sleep $SLEEP_TIME
done

exit 1