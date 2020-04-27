#!/usr/bin/env bash

usage() { 
    cat << EOF

Upload Multiple Audio Files for decoding (using cURL)
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
    CLIENT_COMMAND="curl -X PUT -T ${audio} --header \"model: SingaporeCS_0519NNET3\" -H \"Content-Type: audio/x-wav; charset=utf-8\" -H \"Accept-Charset: utf-8, iso-8859-1;q=0.5\" \"https://speechlab-online.dev.aisingapore.org/client/dynamic/recognize\""
    eval $CLIENT_COMMAND
done

exit 1