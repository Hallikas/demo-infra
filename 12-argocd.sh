echo "Verify CLUSTER value in this file, and remove/comment this line" && exit
CLUSTER=kube.semilab.net

kubectl create ns argocd

### REDIS
#helm show values oci://registry-1.docker.io/bitnamicharts/redis > redis.values.default.yaml
helm upgrade --install=true --create-namespace -n argocd \
	redis oci://registry-1.docker.io/bitnamicharts/redis \
	--set usePassword="false" \
	--set architecture="standalone" \
	--set master.pdb.create="false" \
	--set master.persistence.enabled="false" \
	--set master.persistence.size="256Mi" \
	--set master.persistentVolumeClaimRetentionPolicy.enabled="false" \
	--set master.persistentVolumeClaimRetentionPolicy.whenDeleted="Delete"

### ARGOCD
helm repo add argo https://argoproj.github.io/argo-helm
#helm show values argo/argo-cd > argocd.values.default.yaml
helm upgrade argocd argo/argo-cd \
	--install=true --create-namespace -n argocd \
	--set global.domain=argocd.${CLUSTER} \
	--set server.url=https://argocd.${CLUSTER} \
\
	--set server.ingress.enabled="true" \
	--set server.ingress.ingressClassName=nginx \
	--set configs.params."server\.insecure=true" \
\
 	--set redis.enabled="false" \
        --set redis.persistence.enabled="false" \
 	--set externalRedis.enabled="true" \
 	--set externalRedis.existingSecret=redis \
 	--set externalRedis.host=redis-master \
\
        --set controller.pdb.create="false" \
        --set applicationSet.pdb.create="false" \
        --set notifications.pdb.create="false" \
        --set server.pdb.create="false" \
        --set repoServer.pdb.create="false" \
        --set dex.pdb.create="false" \
\
#       --set controller.resources.limits.memory="1024Mi" \
