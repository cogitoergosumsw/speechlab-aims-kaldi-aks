#!/bin/bash
/home/appuser/opt/kubectl delete job $(/home/appuser/opt/kubectl get job -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}') >> /home/appuser/opt/job.log

exit 0