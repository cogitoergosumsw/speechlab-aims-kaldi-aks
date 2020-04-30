import schedule, time, subprocess, logging

def job():
    logging.info("Checking completed jobs and delete them")
    subprocess.Popen(['bash', '/home/appuser/opt/cronjob_delete_kubenetes_jobs.sh'])  #async

# https://savvytime.com/converter/sgt-to-utc
# SGT 3am = UCT 7pm 
# for debug : schedule.every(1).minutes.do(job)
schedule.every().day.at("19:00").do(job)

while True:
    schedule.run_pending()
    time.sleep(1)