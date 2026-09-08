#echo "Verify CLUSTER value in this file, and remove/comment this line" && exit
CLUSTER=kube.semilab.net

[ -e gitea.values.yaml ] || cat <<"EOF" > gitea.values.yaml
gitea:
  config:
    APP_NAME: "Demo Git"
    server:
      DOMAIN: git.${CLUSTER}}
      ROOT_URL: https://git.${CLUSTER}}/
      SSH_PORT: 2222 # rootful image
      SSH_LISTEN_PORT: 2222 # rootless image
    service:
      DISABLE_REGISTRATION: true
      REQUIRE_SIGNIN_VIEW: true
    database:
      DB_TYPE: sqlite3
#     DB_TYPE: postgres
    session:
      PROVIDER: memory
    cache:
      ADAPTER: memory
    queue:
      TYPE: channel

    mailer:
      ENABLED: true
      FROM: git@${CLUSTER}
      PROTOCOL: smtp
      SMTP_ADDR: smtp.mail.svc
      SMTP_PORT: "25"
EOF

kubectl create ns gitea
[ -e gitea-pvc.yaml ] || cat <<'EOF' > gitea-pvc.yaml
#---
#apiVersion: v1
#kind: PersistentVolume
#metadata:
#  name: pv-gitea
#spec:
#  accessModes:
#  - ReadWriteOnce
#  capacity:
#    storage: 1Gi
#  hostPath:
#    path: /data/gitea
#    type: DirectoryOrCreate
#  persistentVolumeReclaimPolicy: Retain
#  storageClassName: local-path
#  volumeMode: Filesystem
#  nodeAffinity:
#    required:
#      nodeSelectorTerms:
#      - matchExpressions:
#        - key: kubernetes.io/hostname
#          operator: In
#          values:
#          - demo
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-gitea
  namespace: gitea
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: gitea
    meta.helm.sh/release-namespace: gitea
spec:
  accessModes:
    - ReadWriteOnce
# storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
# volumeName: pv-gitea
EOF
kubectl apply -f gitea-pvc.yaml

#helm show values oci://docker.gitea.com/charts/gitea > gitea.values.default.yaml
helm upgrade --install gitea oci://docker.gitea.com/charts/gitea \
	-n gitea --create-namespace \
	--values gitea.values.yaml \
\
	--set ingress.enabled=true \
	--set ingress.className=nginx \
	--set ingress.hosts[0].host=git.${CLUSTER} \
\
	--set gitea.admin.username=admin \
	--set gitea.admin.password=salainen \
	--set gitea.admin.passwordMode=initialOnlyRequireReset \
\
	--set global.storageClass=longhorn \
	--set persistence.claimName=pvc-gitea \
	--set persistence.size=1Gi \
\
	--set valkey-cluster.enabled=false \
	--set valkey.enabled=false \
	--set postgresql-ha.enabled=false \
	--set postgresql.enabled=false \
	--set postgresql.primary.persistence.size=1Gi \

exit

# --set persistence.storageClass=local-path \
# --set name=prod
# --set-string long_int=1234567890
# --set-file my_script=dothings.sh
# --set-json 'master.sidecars=[{"a": "1", "b": "2"}]'
