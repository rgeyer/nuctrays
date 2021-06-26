local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local config = import 'config.libsonnet';

local container = k.core.v1.container,
      configMap = k.core.v1.configMap,
      containerPort = k.core.v1.containerPort,
      statefulSet = k.apps.v1.statefulSet,
      service = k.core.v1.service,
      envFrom = k.core.v1.envFromSource,
      secret = k.core.v1.secret,
      pv = k.core.v1.persistentVolume,
      pvc = k.core.v1.persistentVolumeClaim,
      volumeMount = k.core.v1.volumeMount;

config {
  mysql_cm:
    configMap.new('mad-config') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'mad.cnf': importstr './mad.cnf',
    }),

  mysql_data_pv:
    pv.new('mysql-data-pv') +
    pv.spec.withAccessModes('ReadWriteOnce') +
    pv.spec.withCapacity({'storage': '1Gi'}) +
    pv.spec.withStorageClassName('nfs-storage') +
    pv.spec.withMountOptions([
      'hard',
      'nfsvers=4.1',
    ]) +
    pv.spec.nfs.withPath('/mnt/brick/nfs/mysql') +
    pv.spec.nfs.withServer('192.168.42.102'),

  mysql_data_pvc:
    pvc.new('mysql-data-pvc') +
    pvc.spec.withAccessModes('ReadWriteOnce') +
    pvc.spec.withStorageClassName('nfs-storage') +
    pvc.spec.withVolumeName('mysql-data-pv') +
    pvc.spec.resources.withRequests({'storage': '1Gi'}) +
    pvc.mixin.metadata.withNamespace($._config.namespace),

  mysql_secret:
    secret.new('mysql', {}) +
    secret.withStringData({
      'MYSQL_ROOT_PASSWORD': $._config.mysql.root_password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  mysql_container::
    container.new('mysql', $._images.mysql) +
    container.withArgsMixin(k.util.mapToFlags($._config.mysql.server_args)) +
    container.withPorts(
      [containerPort.new('mysql-tcp', $._config.mysql.port)],
    ) +
    container.withEnvFrom(envFrom.secretRef.withName('mysql')),

  mysql_statefulset:
    statefulSet.new('mysql', 1, $.mysql_container) +
    statefulSet.spec.withServiceName('mysql') +
    statefulSet.mixin.metadata.withNamespace($._config.namespace) +
    k.util.pvcVolumeMount('mysql-data-pvc', '/var/lib/mysql', false) +
    k.util.configMapVolumeMount($.mysql_cm, '/etc/mysql/conf.d') +
    statefulSet.mixin.metadata.withNamespace($._config.namespace),

  mysql_service:
    k.util.serviceFor($.mysql_statefulset) +
    service.mixin.metadata.withNamespace($._config.namespace),
}
