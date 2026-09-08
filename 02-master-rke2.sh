#!/bin/bash

echo "Set SYSTEMURL value in this file, and remove/comment this line" && exit

# This should be DNS name for Master nodes (DNS name should point to ALL
# nodes that serves as master/control-plane)
SYSTEMURL=kube.semilab.net

# All nodes in cluster must use same TOKEN, first node can be randomized
TOKEN=$(openssl rand -hex 48)

#cat <<'EOF' > /etc/resolv-ipv4.conf
#nameserver 8.8.8.8
#nameserver 1.1.1.1
#search .
#EOF

mkdir -p /etc/rancher/rke2
echo -n > /etc/rancher/rke2/config.yaml
cat <<EOF > /etc/rancher/rke2/config.yaml
#server: https://${SYSTEMURL}:9345
token: ${TOKEN}
tls-san:
 - ${SYSTEMURL}
#resolv-conf: /etc/resolv-ipv4.conf
service-node-port-range: 0-65535
kubelet-arg:
  - "max-pods=250"
  - "eviction-hard=imagefs.available<1%,nodefs.available<1%"
  - "eviction-minimum-reclaim=imagefs.available=1Mi,nodefs.available=1Mi"
disable:
# - rke2-ingress-nginx
  - rke2-snapshot-controller
  - rke2-snapshot-controller-crd
  - rke2-snapshot-validation-webhook
kube-scheduler-extra-env: "TZ=Europe/Helsinki"
ingress-controller: ingress-nginx
control-plane-resource-requests:
  - kube-apiserver-cpu=130m
  - kube-apiserver-memory=2300M
  - kube-scheduler-cpu=5m
  - kube-scheduler-memory=100M
  - etcd-cpu=50m
EOF

mkdir -p /var/lib/rancher/rke2/server/manifests
grep -v "^#" <<'EOF' > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml
---
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-ingress-nginx
  namespace: kube-system
spec:
  valuesContent: |-
    controller:
      tolerations:
      - effect: NoSchedule
        key: CriticalAddonsOnly
        operator: Exists
      extraArgs:
        tcp-services-configmap: $(POD_NAMESPACE)/tcp-services
        udp-services-configmap: $(POD_NAMESPACE)/udp-services
        default-ssl-certificate: cert-manager/tls-default-cert
      config:
        force-ssl-redirect: "true"
        use-forwarded-headers: "true"
        enable-real-ip: "true"
        proxy-add-original-uri-header: "true"
        log-format-escape-json: "true"
        map-hash-bucket-size: "128"
        proxy-body-size: 150M
        use-geoip2: "true"
        proxy-set-headers: kube-system/rke2-ingress-nginx-headers
      containerPort:
        http: 80
        https: 443
        ssh2: 2222
        registry: 5000
##    metrics:
##      enabled: true
##      serviceMonitor:
##        enabled: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: udp-services
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tcp-services
  namespace: kube-system
data:
  "2222": gitea/gitea-ssh:22
  "5000": registry/registry:5000
---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: kube-system
  name: rke2-ingress-nginx-headers
data:
  X-Using-Nginx-Controller: "true"
EOF

curl -sfL https://get.rke2.io | sh -
grep -q "rancher/rke2" ~/.profile || echo 'PATH=/var/lib/rancher/rke2/bin/:${PATH}' >> ~/.profile
systemctl enable rke2-server.service
systemctl start rke2-server.service

mkdir -p /root/.kube
cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
chmod 600 /root/.kube/config

### Kube Tools
snap install kubectl --classic
snap install kubeadm --classic

# Add our custom labels
kubectl label nodes $(hostname) hostpath=true
