local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local pv = k.core.v1.persistentVolume,
      pvc = k.core.v1.persistentVolumeClaim;

{
  new(namespace, nfsHost, nfsPath, name='', storageClass='nfs-storage'):: {
    local this = self,
    local basename = if name != '' then name else super.uuid,

    pv:
      pv.new(basename+'-pv') +
      pv.spec.withAccessModes('ReadWriteOnce') +
      pv.spec.withCapacity({'storage': '1Gi'}) +
      pv.spec.withStorageClassName(storageClass) +
      pv.spec.withMountOptions([
        'hard',
        'nfsvers=4.1',
      ]) +
      pv.spec.nfs.withPath(nfsPath) +
      pv.spec.nfs.withServer(nfsHost),

    pvc:
      pvc.new(basename+'-pvc') +
      pvc.spec.withAccessModes('ReadWriteOnce') +
      pvc.spec.withStorageClassName(storageClass) +
      pvc.spec.withVolumeName(basename+'-pv') +
      pvc.spec.resources.withRequests({'storage': '1Gi'}) +
      pvc.mixin.metadata.withNamespace(namespace)
  }
}
