local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount,
      statefulSet = k.apps.v1.statefulSet,
      service = k.core.v1.service;

local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local staticIp = '10.43.0.20';
local namespace = 'sharedsvc';

{
  media_pvc: nfspvc.new(
    namespace,
    '192.168.1.20',
    '/mnt/ZeroThru5/Media/ps3',
    'ps3media',
  ),

  container::
    container.new('ps3netsrv', 'shawly/ps3netsrv') +
    container.withEnvMap({
      TZ: 'America/Los_Angeles',
      USER_ID: '3001',
      GROUP_ID: '3001',
    }) +
    container.withPorts([
      containerPort.new('media', 38008),
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('ps3media', '/games'),
    ]),

  statefulset:
    statefulSet.new('ps3netsrv', 1, $.container, podLabels={ name: 'ps3netsrv' }) +
    statefulSet.spec.withServiceName('ps3netsrv') +
    statefulSet.mixin.metadata.withNamespace(namespace) +
    statefulSet.spec.template.metadata.withAnnotations({
      'cni.projectcalico.org/ipAddrs': '["%(ip)s"]' % { ip: staticIp },
    }) +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromPersistentVolumeClaim('ps3media', 'ps3media-pvc'),
    ]),    

  service:
    k.util.serviceFor($.statefulset) +
    service.mixin.metadata.withNamespace(namespace),
}
