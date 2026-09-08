#### Continue after system is fully running
### Cert-Manager is mandatory for Rancher

echo "Verify CLUSTER value in this file, and remove/comment this line" && exit

helm repo add jetstack https://charts.jetstack.io
helm repo update

CLUSTER=kube.semilab.net

kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
helm upgrade --install=true cert-manager jetstack/cert-manager \
	--namespace cert-manager --create-namespace \
	--set crds.enabled=true \
	--set crds.keep=true

cat <<EOF|kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tls-default-cert
  namespace: cert-manager
spec:
  secretName: tls-default-cert
  issuerRef:
    name: default
    kind: ClusterIssuer
    group: cert-manager.io
  commonName: "${CLUSTER}"
  dnsNames:
    - "${CLUSTER}"
    - "*.${CLUSTER}"
EOF
