import time,os, logging, thread
from ws4py.client.threadedclient import WebSocketClient

IDLE_TIMEOUT = 15*60

class BaseServerWebsocket(WebSocketClient):

    def __init__(self, url, heartbeat_freq):
            WebSocketClient.__init__(self, url=url, heartbeat_freq=heartbeat_freq)
            self.start_time = time.time()


    def guard_idle_run_once_worker(self):
        while self.state == self.STATE_CONNECTED:
            if time.time() - self.start_time  > IDLE_TIMEOUT:
                logging.warning("%s: Worker has more than %d seconds idle, shutting down" % (self.request_id, IDLE_TIMEOUT))
                self.finish_request()
                self.close()
                return
            time.sleep(1)

    def monitor_idle_run_once_worker(self):
        if os.getenv('RUN_FREQ', False) == 'ONCE':
            logging.info('start monitor idle RUN_FREQ=ONCE worker for more than {} seconds'.format(IDLE_TIMEOUT))
            thread.start_new_thread(self.guard_idle_run_once_worker, ())