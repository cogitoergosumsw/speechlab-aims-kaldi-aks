#!/bin/bash
set -u

NAMESPACE=kaldi-test

git clone https://github.com/helm/charts.git /tmp/pro-fana
cp -r /tmp/pro-fana/stable/prometheus ./docker/helm/prometheus/
cp -r /tmp/pro-fana/stable/grafana ./docker/helm/grafana/
rm -rf /tmp/pro-fana

for i in {0..1}; do
    MASTER_IP=$(kubectl get pods --selector=app.kubernetes.io/name=kaldi-feature-test-master -o jsonpath="{.items[$i].status.podIP}")
    sed -i "s/MASTER_CLUSTER_IP_$i/$MASTER_IP/g" monitoring/values.yaml 
done

helm install --name prometheus \
    --namespace $NAMESPACE docker/helm/prometheus
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
    docker/helm/grafana/
echo "Waiting for Grafana to be deployed within the cluster..."
sleep 10
export GRAFANA_ADMIN_PW=$(
    kubectl get secret --namespace $NAMESPACE grafana -o jsonpath="{.data.admin-password}" | base64 --decode
    echo
)
kubectl patch svc grafana \
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

kubectl config set-context --current --namespace $NAMESPACE