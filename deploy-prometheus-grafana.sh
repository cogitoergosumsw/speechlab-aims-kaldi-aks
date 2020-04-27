#!/bin/bash
set -u

NAMESPACE=kaldi-test
KUBE_NAME=kaldi-feature-test

# Setup Prometheus and Grafana
git clone https://github.com/helm/charts.git /tmp/pro-fana

helm install --name prometheus \
    --set server.global.scrape_interval='10s' \
    --set server.global.scrape_timeout='10s' \
    --set server.persistentVolume.size='35Gi' \
    --set server.global.evaluation_interval='10s' \
    --namespace $NAMESPACE \
    /tmp/pro-fana/stable/prometheus

echo "Waiting for Prometheus to be deployed within the cluster..."
sleep 3
export PROMETHEUS_POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
echo "Prometheus is deployed on K8s!"
cp monitoring/kaldi-grafana-dashboard.json /tmp/pro-fana/stable/grafana/dashboards/kaldi-grafana-dashboard.json

kubectl apply -f monitoring/grafana-config.yaml
helm install -f monitoring/grafana-values.yaml \
    --name grafana \
    --namespace $NAMESPACE \
    --set persistence.enabled=true \
    --set persistence.accessModes={ReadWriteOnce} \
    --set persistence.size=5Gi \
    /tmp/pro-fana/stable/grafana
echo "Waiting for Grafana to be deployed within the cluster..."
sleep 10
export GRAFANA_ADMIN_PW=$(
    kubectl get secret --namespace $NAMESPACE grafana -o jsonpath="{.data.admin-password}" | base64 --decode
    echo
)
kubectl patch svc grafana \
    --namespace "$NAMESPACE" \
    -p '{"spec": {"type": "LoadBalancer"}}'

sleep 60

export MASTER_SERVICE="$KUBE_NAME-master"

export GRAFANA_SERVICE_IP=$(kubectl get svc grafana \
    --namespace $NAMESPACE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
export MASTER_SERVICE_IP=$(kubectl get svc $MASTER_SERVICE \
    --namespace $NAMESPACE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat > cluster-info.txt <<EOF

KALDI SPEECH RECOGNITION SYSTEM deployed on Kubernetes
###################################################################

Access the Master pod service at http://$MASTER_SERVICE_IP

You may access the speech recognition function using a live microphone or by passing in an audio file.

For example,

python3 client/client_3_ssl.py -u ws://$MASTER_SERVICE_IP/client/ws/speech -r 32000 -t abc --model="SingaporeCS_0519NNET3" client/audio/episode-1-introduction-and-origins.wav

OR

curl  -X PUT -T docker/audio/long/episode-1-introduction-and-origins.wav --header "model: SingaporeCS_0519NNET3" --header "content-type: audio/x-wav" "http://$MASTER_SERVICE_IP/client/dynamic/recognize"

###################################################################


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Grafana is deployed on K8s at http://$GRAFANA_SERVICE_IP

Login to Grafana dashboard with the following credentials,

User: admin
Password: $GRAFANA_ADMIN_PW

The custom Kaldi Speech Recognition Kubernetes dashboard is available in the General folder.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

EOF

# clean up Prometheus and Grafana helm files
rm -rf /tmp/pro-fana

echo -e "\e[32mAll information about the Kaldi Test Kubernetes cluster is available in cluster-info.txt in this directory! \e[0m"

exit 0
