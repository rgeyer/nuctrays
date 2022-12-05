local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount,
      statefulSet = k.apps.v1.statefulSet,
      service = k.core.v1.service;

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

local staticIp = '10.43.0.19';
local namespace = 'sharedsvc';

{
  media_pvc: nfspvc.new(
    namespace,
    '192.168.42.10',
    '/kubestore/plex/media',
    'jellyfinmedia',
  ),

  config_pvc: nfspvc.new(
    namespace,
    '192.168.42.10',
    '/kubestore/jellyfin',
    'jellyfinconfig',
  ),

  container::
    container.new('jellyfin', 'lscr.io/linuxserver/jellyfin') +
    container.withEnvMap({
      TZ: 'America/Los_Angeles',
      JELLYFIN_PublishedServerUrl: staticIp,
    }) +
    container.withPorts([
      containerPort.new('http-metrics', 8096)
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('jellyfinmedia', '/data'),
      volumeMount.new('jellyfinconfig', '/config'),
    ]) +
    container.resources.withRequests({memory: "2.4G"}) +
    container.resources.withLimits({memory: "3G"}),

  statefulset:
    statefulSet.new('jellyfin', 1, $.container, podLabels={name: 'jellyfin'}) +
    statefulSet.spec.withServiceName('jellyfin') +
    statefulSet.mixin.metadata.withNamespace(namespace) +
    statefulSet.spec.template.metadata.withAnnotations({
      'cni.projectcalico.org/ipAddrs': '["%(ip)s"]' % { ip: staticIp },
    }) +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromPersistentVolumeClaim('jellyfinmedia', 'jellyfinmedia-pvc'),
      volume.fromPersistentVolumeClaim('jellyfinconfig', 'jellyfinconfig-pvc'),
    ]),

  service:
    k.util.serviceFor($.statefulset) +
    service.mixin.metadata.withNamespace(namespace),
  
  ingress:
    traefikingress.newIngressRoute('jellyfin', namespace, 'jellyfin.ryangeyer.com', 'jellyfin', 8096)
}
