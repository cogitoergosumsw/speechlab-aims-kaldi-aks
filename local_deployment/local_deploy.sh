#!/bin/bash
set -eu

# installing helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get >/tmp/install-helm.sh
chmod u+x /tmp/install-helm.sh
/tmp/install-helm.sh

export KUBE_NAME=kaldi-feature-test
export NAMESPACE=kaldi-test