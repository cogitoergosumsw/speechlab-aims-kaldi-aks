#!/usr/bin/env bash

usage() {
    cat << EOF

Test Sending Multiple Jobs via redis-cli for decoding
----------------------------------------------------------------------------------------------------------------------------------------
Aim of the this script is to run multiple jobs simultaneously to see if the server is able to handle
the load (test if load balancing working?)

Steps to take before execute this script:
    1. Ensure that the input files are already in the blob storage
    2. this script has execute permissions if not - chmod +x test_redis_cli_multi_jobs.sh
    3. Create a RequestBin account and have your own callback URL
    4. redis-cli is installed
    5. this script is run inside the directory where redis-cli is installed e.g redis-5.0.5/src
----------------------------------------------------------------------------------------------------------------------------------------

EOF
    1>&2
    exit 2
}

if [ "$1" == "--help" ]; then
    usage
fi

# test english and eng/chi models
# loaded 50 english episodes in the blob storage input
IFS=$'\n'
for i in {1..5}; do
    if [ $(($i % 2)) -eq 0 ]; then
        SELECTED_MODEL="SingaporeCS_0519NNET3"
        CALLBACK="https://en8bz79x1k2th.x.pipedream.net/"
    elif [ $(($i % 2)) -eq 1 ]; then
        SELECTED_MODEL="SingaporeEnglish_0519NNET3"
        CALLBACK="https://enghx2b1l06jh.x.pipedream.net/"
    fi
    INPUT_FILE_PATH="input/episode-${i}.wav"
    
    cat >> commands.txt << EOL
auth cae3ddf8fd71de4b48d891180d8280310f0a828697c3e71e393ead6c2941d2a0
rpush speechlab-aks-prod-offline-queue '{"selected_model":"${SELECTED_MODEL}","input_file_path":"${INPUT_FILE_PATH}", "id": "simul-${i}","callback":"${CALLBACK}"}'
EOL

done

# test chinese models
# loaded 5 chinese episodes in the blob storage input
for j in {1..5}; do
    SELECTED_MODEL="SingaporeMandarin_0519NNET3"
    CALLBACK="https://en6u1rnbhmvzc.x.pipedream.net/"
    INPUT_FILE_PATH="input/chinese-episode-${j}.wav"

    cat >> commands.txt << EOL
auth cae3ddf8fd71de4b48d891180d8280310f0a828697c3e71e393ead6c2941d2a0
rpush speechlab-aks-prod-offline-queue '{"selected_model":"${SELECTED_MODEL}","input_file_path":"${INPUT_FILE_PATH}", "id": "simul-chinese-${j}","callback":"${CALLBACK}"}'
EOL

done
cat commands.txt

cat commands.txt | ./redis-cli -h 20.184.61.92

rm commands.txt

exit 0

