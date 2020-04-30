#!/bin/bash
/home/appuser/opt/kubectl delete job $(/home/appuser/opt/kubectl get job --namespace $NAMESPACE -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}') --namespace $NAMESPACE