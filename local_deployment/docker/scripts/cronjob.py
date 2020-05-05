import schedule, time, subprocess, logging

def job():
    logging.info("Checking completed jobs and delete them")
    subprocess.Popen(['bash', '/home/appuser/opt/cronjob_delete_kubernetes_jobs.sh'])  #async

# https://savvytime.com/converter/sgt-to-utc
# SGT 3am = UCT 7pm 
# schedule.every(5).minutes.do(job) (for debug)
schedule.every().day.at("19:00").do(job)

while True:
    schedule.run_pending()
    time.sleep(1)