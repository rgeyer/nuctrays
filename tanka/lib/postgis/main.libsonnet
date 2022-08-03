local k = import 'ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      service = k.core.v1.service,
      statefulSet = k.apps.v1.statefulSet,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount;

local nfspvc = import 'k8sutils/nfspvc.libsonnet';

{
  perstore:
    nfspvc.new($._config.namespace, $._config.postgis.pvc.nfsHost, $._config.postgis.pvc.nfsPath, 'postgisdata'),

  cm:
    configMap.new('postgiscfg') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'postgresql.conf': "listen_addresses = '0.0.0.0'",
    }),

  container::
    container.new('postgis', $._images.postgis) +
    container.withArgs([
      '-c',
      'config_file=/etc/postgresql/postgresql.conf',
    ]) +
    container.withEnv([
      k.core.v1.envVar.fromSecretRef('POSTGRES_PASSWORD', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('postgres', 5432),
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('config', '/etc/postgresql'),
      volumeMount.new('data', '/var/lib/postgresql/data'),
    ]),

  statefulset:
    statefulSet.new('postgis', 1, $.container) +
    statefulSet.spec.withServiceName('postgis') +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromConfigMap('config', 'postgiscfg') +
      volume.configMap.withDefaultMode(420),

      volume.fromPersistentVolumeClaim('data', 'postgisdata-pvc'),
    ]) +
    statefulSet.mixin.metadata.withNamespace($._config.namespace),

  service:
    k.util.serviceFor($.statefulset) +
    service.mixin.metadata.withNamespace($._config.namespace),
}
