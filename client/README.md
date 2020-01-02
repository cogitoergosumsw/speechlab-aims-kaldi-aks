# Load Balancing Related tests

Folder contains test related files for AIMS-SPEECHLAB deployment

## Client script

The client.py file allows one to connect to the server that can transcribe audio files or audio from live microphone input.

### Sample command to run

Live Microphone Input

- `python client_2_ssl.py  -o stream  -u ws://kaldi-feature-test.southeastasia.cloudapp.azure.com/client/ws/speech  -r 32000 -t abc --model="SingaporeCS_0519NNET3"`
- `python3 client_3_ssl.py  -o stream  -u ws://kaldi-feature-test.southeastasia.cloudapp.azure.com/client/ws/speech  -r 32000 -t abc --model="SingaporeCS_0519NNET3"`

Audio File

- `python client_2_ssl.py -u ws://kaldi-feature-test.southeastasia.cloudapp.azure.com/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" audio/episode-1-introduction-and-origins.wav`
- `python3 client_3_ssl.py -u ws://kaldi-feature-test.southeastasia.cloudapp.azure.com/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" audio/episode-1-introduction-and-origins.wav`

### Available models

1. SgEnglish_AISG_2019
2. SingaporeCS_0519NNET3
3. SingaporeEnglish_0519NNET3
4. SingaporeMandarin_0519NNET3
