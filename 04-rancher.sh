### Rancher
echo "Set SYSTEMURL value in this file, and remove/comment this line" && exit

SYSTEMURL=kube.semilab.net

REPO=latest
helm repo add rancher-${REPO} https://releases.rancher.com/server-charts/${REPO}
helm repo update

kubectl create namespace cattle-system
helm upgrade --install=true rancher rancher-${REPO}/rancher \
	--namespace cattle-system \
	--set replicas=1 \
	--set hostname=${SYSTEMURL} \
	--set tls=external
#	--set ingress.extraAnnotations.'cert-manager\.io/cluster-issuer'=default

# Wait until ready
until kubectl get secret --namespace cattle-system bootstrap-secret 2> /dev/null;do sleep 4;done
echo https://${SYSTEMURL}/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')
