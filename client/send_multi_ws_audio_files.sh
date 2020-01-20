#!/usr/bin/env bash

usage() {
    cat <<EOF

Sending Multiple Jobs via websocket for decoding
----------------------------------------------------------------------------------------------------------------------------------------
Aim of the this script is to run multiple jobs simultaneously to see if the server is able to handle
the load (test if load balancing working?)
----------------------------------------------------------------------------------------------------------------------------------------

EOF
    1>&2
    exit 2
}

if [ "$1" == "--help" ]; then
    usage
fi

# change the IP address of the master service accordingly
for i in {1..100}; do
    python3 client/client_3_ssl.py -u ws://20.43.179.15/client/ws/speech \
        -r 32000 -t abc --model="SingaporeCS_0519NNET3" \
        client/audio/episode-1-introduction-and-origins.wav &
    sleep 2
done

exit 0