local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local nfspvc = import 'k8sutils/nfspvc.libsonnet',
      configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      cronJob = k.batch.v1beta1.cronJob;

{

  bkup_pvc: nfspvc.new(
    $._config.namespace,
    $._config.backups.pvc.nfsHost,
    $._config.backups.pvc.nfsPath,
    'backups',
  ),

  cm:
    configMap.new('backup-scripts') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'common.sh': importstr './scripts/common.sh',
      'etcdbak.sh': importstr './scripts/etcdbak.sh',
      // Note: Mysql backup cronjobs are defined in each mysql environment
      'mysqlbak.sh': importstr './scripts/mysqlbak.sh',
      'mysqlreplicabak.sh': importstr './scripts/mysqlreplicabak.sh',
    }),

  etcd_container::
    container.new('etcd', $._images.etcdbkup) +
    container.withEnv([
      k.core.v1.envVar.fromFieldPath('HOSTNAME', 'spec.nodeName'),
      k.core.v1.envVar.fromFieldPath('HOSTIP', 'status.hostIP'),
      k.core.v1.envVar.new('BACKUPROOT', '/backup'),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('etcdtls', '/etcdtls'),
      k.core.v1.volumeMount.new('scripts', '/scripts'),
      k.core.v1.volumeMount.new('backup', '/backup'),
    ]) +
    container.withWorkingDir('/scripts') +
    container.withCommand(['bash', '/scripts/etcdbak.sh']) +
    container.securityContext.withRunAsUser(0),

  etcd:
    cronJob.new('etcdbkup', '30 2 * * *', $.etcd_container) +
    cronJob.mixin.metadata.withNamespace($._config.namespace) +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withNodeSelector({etcdnode: "true"}) +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromHostPath('etcdtls', '/etc/ssl/etcd/ssl'),
      k.core.v1.volume.fromConfigMap('scripts', 'backup-scripts'),
      k.core.v1.volume.fromPersistentVolumeClaim('backup', 'backups-pvc'),
    ]),
}
