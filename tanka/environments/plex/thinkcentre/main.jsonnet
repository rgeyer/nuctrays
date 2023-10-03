local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount,
      statefulSet = k.apps.v1.statefulSet,
      service = k.core.v1.service;

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

local staticIp = '10.43.0.20';
local namespace = 'sharedsvc';

{
  media_pvc: nfspvc.new(
    namespace,
    '192.168.1.20',
    '/mnt/ZeroThru5/Media',
    'plexmedia',
  ),

  config_pvc: nfspvc.new(
    namespace,
    '192.168.1.20',
    '/mnt/ZeroThru5/k8s/thinkcentre/plexconfig',
    'plexconfig',
  ),

  container::
    container.new('plex', 'linuxserver/plex') +
    container.withEnvMap({
      TZ: 'America/Los_Angeles',
      VERSION: 'docker',
      ADVERTISE_IP: 'http://' + staticIp + ':32400',
      PUID: '911',
      PGID: '911',
      // PLEX_CLAIM: '', // Required on the first start, then never again because it gets stored in the config
    }) +
    container.withPorts([
      containerPort.new('plex', 32400)
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('plexmedia', '/data'),
      volumeMount.new('plexconfig', '/config'),
    ]),

  statefulset:
    statefulSet.new('plex', 1, $.container, podLabels={name: 'plex'}) +
    statefulSet.spec.withServiceName('plex') +
    statefulSet.mixin.metadata.withNamespace(namespace) +
    statefulSet.spec.template.metadata.withAnnotations({
      'cni.projectcalico.org/ipAddrs': '["%(ip)s"]' % { ip: staticIp },
    }) +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromPersistentVolumeClaim('plexmedia', 'plexmedia-pvc'),
      volume.fromPersistentVolumeClaim('plexconfig', 'plexconfig-pvc'),
    ]),

  service:
    k.util.serviceFor($.statefulset) +
    service.mixin.metadata.withNamespace(namespace),
  
  ingress:
    traefikingress.newIngressRoute('plex', namespace, 'plex.ryangeyer.com', 'plex', 32400)
}
