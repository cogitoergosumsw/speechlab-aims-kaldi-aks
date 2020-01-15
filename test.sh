#!/bin/bash
set -u

NAMESPACE=kaldi-test

# Setup Prometheus and Grafana
git clone https://github.com/helm/charts.git /tmp/pro-fana

helm install --name prometheus \
    --namespace $NAMESPACE \
    /tmp/pro-fana/stable/prometheus
    # -f monitoring/values.yaml 

echo "Waiting for Prometheus to be deployed within the cluster..."
sleep 3
export PROMETHEUS_POD_NAME=$(kubectl get pods --namespace $NAMESPACE -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
echo "Prometheus is deployed on K8s!"

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
kubectl patch svc prometheus-server \
    --namespace "$NAMESPACE" \
    -p '{"spec": {"type": "LoadBalancer"}}'
sleep 30
export GRAFANA_SERVICE_IP=$(kubectl get svc grafana \
    --namespace $NAMESPACE \
    --output jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat <<EOF

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Grafana is deployed on K8s at http://$GRAFANA_SERVICE_IP!

Login to Grafana dashboard with the following credentials,

User: admin
Password: $GRAFANA_ADMIN_PW

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

EOF

# clean up Prometheus and Grafana helm files
rm -rf /tmp/pro-fana

exit 0