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
    python3 client/client_3_ssl.py -u ws://20.43.144.54/client/ws/speech \
        -r 32000 -t abc --model="SingaporeCS_0519NNET3" \
        docker/audio/long/episode-2-government-of-the-people-and-by-the-people.wav &
    sleep 5
done

exit 0