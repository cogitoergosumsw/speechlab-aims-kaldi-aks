import argparse
from ws4py.client.threadedclient import WebSocketClient
import time
import threading
import sys
import urllib
import Queue
import json
import time
import os
import ssl

import pyaudio

FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000
CHUNK = int(RATE / 10)  # 100ms

# audio = pyaudio.PyAudio()
def rate_limited(maxPerSecond):
    minInterval = 1.0 / float(maxPerSecond)
    def decorate(func):
        lastTimeCalled = [0.0]
        def rate_limited_function(*args,**kargs):
            elapsed = time.clock() - lastTimeCalled[0]
            leftToWait = minInterval - elapsed
            if leftToWait>0:
                time.sleep(leftToWait)
            ret = func(*args,**kargs)
            lastTimeCalled[0] = time.clock()
            return ret
        return rate_limited_function
    return decorate


class MyClient(WebSocketClient):

    def __init__(self, mode, audiofile, url, protocols=None, extensions=None, heartbeat_freq=None, byterate=32000,
                 save_adaptation_state_filename=None, ssl_options=None, send_adaptation_state_filename=None):
        super(MyClient, self).__init__(url, protocols, extensions, heartbeat_freq)
        self.final_hyps = []
        self.byterate = byterate
        self.final_hyp_queue = Queue.Queue()
        self.save_adaptation_state_filename = save_adaptation_state_filename
        self.send_adaptation_state_filename = send_adaptation_state_filename

        self.ssl_options = ssl_options or {}

        if self.scheme == "wss":
            # Prevent check_hostname requires server_hostname (ref #187)
            if "cert_reqs" not in self.ssl_options:
                self.ssl_options["cert_reqs"] = ssl.CERT_NONE

        self.isStop = False
        self.audio = pyaudio.PyAudio()
        self.audiofile = audiofile
        self.mode = mode

    @rate_limited(4)
    def send_data(self, data):
        self.send(data, binary=True)

    def opened(self):
        #print "Socket opened!"
        def send_data_to_ws():
            if self.send_adaptation_state_filename is not None:
                print >> sys.stderr, "Sending adaptation state from %s" % self.send_adaptation_state_filename
                try:
                    adaptation_state_props = json.load(open(self.send_adaptation_state_filename, "r"))
                    self.send(json.dumps(dict(adaptation_state=adaptation_state_props)))
                except:
                    e = sys.exc_info()[0]
                    print >> sys.stderr, "Failed to send adaptation state: ",  e

            
            print("Start transcribing...")
            if self.mode == 'stream':
                stream = self.audio.open(format=FORMAT, channels=CHANNELS,
                    rate=RATE, input=True,
                    frames_per_buffer=CHUNK)
                while not self.isStop:
                    data = stream.read(int(self.byterate / 8), exception_on_overflow=False)
                    self.send_data(data) # send data
                
                stream.stop_stream()
                stream.close()
                self.audio.terminate()
            elif self.mode == 'file':
                with self.audiofile as audiostream:
                    for block in iter(lambda: audiostream.read(int(self.byterate/4)), ""):
                        self.send_data(block)

            print >> sys.stderr, "Audio sent, now sending EOS"
            self.send("EOS")


        t = threading.Thread(target=send_data_to_ws)
        t.start()


    def received_message(self, m):
        response = json.loads(str(m))
        if response['status'] == 0:
            if 'result' in response:
                trans = response['result']['hypotheses'][0]['transcript']
                if response['result']['final']:
                    #print >> sys.stderr, trans,
                    self.final_hyps.append(trans)
                    print >> sys.stderr, '\r%s' % trans.replace("\n", "\\n")
                else:
                    print_trans = trans.replace("\n", "\\n")
                    if len(print_trans) > 80:
                        print_trans = "... %s" % print_trans[-76:]
                    print >> sys.stderr, '\r%s' % print_trans,
            if 'adaptation_state' in response:
                if self.save_adaptation_state_filename:
                    print >> sys.stderr, "Saving adaptation state to %s" % self.save_adaptation_state_filename
                    with open(self.save_adaptation_state_filename, "w") as f:
                        f.write(json.dumps(response['adaptation_state']))
        else:
            print >> sys.stderr, "Received error from server (status %d)" % response['status']
            if 'message' in response:
                print >> sys.stderr, "Error message:",  response['message']


    def get_full_hyp(self, timeout=60):
        return self.final_hyp_queue.get(timeout)

    def closed(self, code, reason=None):
        self.final_hyp_queue.put(" ".join(self.final_hyps))

def main():
    parser = argparse.ArgumentParser(description='Command line client for kaldigstserver')
    parser.add_argument('-o', '--option', default="file", dest="mode", help="Mode of transcribing: audio file or streaming")
    parser.add_argument('-u', '--uri', default="ws://localhost:8888/client/ws/speech", dest="uri", help="Server websocket URI")
    parser.add_argument('-r', '--rate', default=32000, dest="rate", type=int, help="Rate in bytes/sec at which audio should be sent to the server. NB! For raw 16-bit audio it must be 2*samplerate!")
    parser.add_argument('-t', '--token', default="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiNWNkMjM2YThiZWNlMWE4ZmI5MTNlNTlmIiwiZXhwIjoxNTU5ODcyNDI0fQ.aBfqru_0T_kg2x7kaxvGTrpJiwChAfJnvmKGz27gcF8", dest="token", help="User token")
    parser.add_argument('-m', '--model', default=None, dest="model", help="model in azure container")
    parser.add_argument('--save-adaptation-state', help="Save adaptation state to file")
    parser.add_argument('--send-adaptation-state', help="Send adaptation state from file")
    parser.add_argument('--content-type', default='', help="Use the specified content type (empty by default, for raw files the default is  audio/x-raw, layout=(string)interleaved, rate=(int)<rate>, format=(string)S16LE, channels=(int)1")
    parser.add_argument('audiofile', nargs='?', help="Audio file to be sent to the server", type=argparse.FileType('rb'), default=sys.stdin)
    args = parser.parse_args()

    if args.mode == 'file' or args.mode == 'stream':
        content_type = args.content_type
        if content_type == '' and args.audiofile.name.endswith(".raw") or args.mode == 'stream':
            content_type = "audio/x-raw, layout=(string)interleaved, rate=(int)%d, format=(string)S16LE, channels=(int)1" %(args.rate/2)

        ws = MyClient(args.mode, args.audiofile, args.uri + '?%s' % (urllib.urlencode([("content-type", content_type)])) + '&%s' % (urllib.urlencode([("token", args.token)])) + '&%s' % (urllib.urlencode([("token", args.token)])) + '&%s' % (urllib.urlencode([("model", args.model)])), byterate=args.rate,
                    save_adaptation_state_filename=args.save_adaptation_state, send_adaptation_state_filename=args.send_adaptation_state)
        
        ws.connect()
        result = ws.get_full_hyp()
        
        print result.encode('utf-8')

    else:
        print('\nTranscribe mode must be file or stream!\n')

if __name__ == "__main__":
    reload(sys)
    sys.setdefaultencoding("utf-8")
    main()