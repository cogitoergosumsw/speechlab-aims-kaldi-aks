#!/usr/bin/env bash

BASE_COMMAND="python client_2_ssl_sw.py -u wss://speechlab-online.dev.aisingapore.org/client/ws/speech -r 32000 -t abc --model=\"SingaporeCS_0519NNET3\""

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

if [ $# -eq 0 ]; then
    usage
fi

for audio in "$@"
do
    CLIENT_COMMAND="${BASE_COMMAND} ${audio}"
    eval $CLIENT_COMMAND
done

exit 1