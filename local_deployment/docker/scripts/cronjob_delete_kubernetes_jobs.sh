#!/bin/bash
kubectl delete job $(kubectl get job -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}') >> /home/appuser/log

exit 0