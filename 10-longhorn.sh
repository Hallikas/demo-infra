### LongHorn

grep -v "^#" <<'EOF'|kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-rwx
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
#reclaimPolicy: Retain
volumeBindingMode: Immediate
parameters:
# numberOfReplicas: "3"
  numberOfReplicas: "2"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
  nfsOptions: "vers=4.2,noresvport,softerr,timeo=600,retrans=5,rw,hard"
EOF

[ -e longhorn.values.yaml ] || cat <<'EOF' > longhorn.values.yaml
defaultSettings:
  allowCollectingLonghornUsageMetrics: false
  disableSchedulingOnCordonedNode: false
  nodeDownPodDeletionPolicy: delete-both-statefulset-and-deployment-pod
  snapshotMaxCount: 32
  defaultDataPath: /data2/longhorn
  createDefaultDiskLabeledNodes: true
  storageMinimalAvailablePercentage: 5
  storageOverProvisioningPercentage: 100
  storageReservedPercentageForDefaultDisk: 2
  taintToleration: CriticalAddonsOnly:NoSchedule
global:
  tolerations:
    - effect: NoSchedule
      key: CriticalAddonsOnly
      operator: Exists
longhornManager:
  tolerations:
    - effect: NoSchedule
      key: CriticalAddonsOnly
      operator: Exists
EOF
mkdir -p /data2/hostpath /data2/longhorn
for NODE in $(kubectl get node -o name|sed 's|^node/||');do
  kubectl label node ${NODE} node.longhorn.io/create-default-disk=config
  kubectl annotate node ${NODE} node.longhorn.io/default-disks-config='[{"name":"data2-longhorn-'${NODE}'","path":"/data2/longhorn","allowScheduling":true,"storageReserved":0}]'
done

helm repo add longhorn https://charts.longhorn.io
helm repo update

#helm show values longhorn/longhorn > longhorn.values.default.yaml
#helm upgrade --install=true longhorn longhorn/longhorn \
#     --namespace longhorn-system --create-namespace \
#     --values longhorn.values.yaml
