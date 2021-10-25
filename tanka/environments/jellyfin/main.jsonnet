local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local container = k.core.v1.container,
volume = k.core.v1.volume,
volumeMount = k.core.v1.volumeMount,
deployment = k.apps.v1.deployment;

local staticIp = '10.42.0.19';
local namespace = 'plex';

{
  media_pvc: nfspvc.new(
    namespace,
    '192.168.42.10',
    '/kubestore/plex/media',
    'jellyfinmedia',
  ),

  config_pvc: nfspvc.new(
    namespace,
    '192.168.42.100',
    '/mnt/brick/nfs/jellyfin',
    'jellyfinconfig',
  ),

  container::
    container.new('jellyfin', 'lscr.io/linuxserver/jellyfin') +
    container.withEnvMap({
      TZ: 'America/Los_Angeles',
      JELLYFIN_PublishedServerUrl: staticIp,
    }) +
    container.withVolumeMountsMixin([
      volumeMount.new('jellyfinmedia', '/data'),
      volumeMount.new('jellyfinconfig', '/config'),
    ]),

  deployment:
    deployment.new('jellyfin', 1, $.container) +
    deployment.mixin.metadata.withNamespace(namespace) +
    deployment.spec.template.metadata.withAnnotations({
      'cni.projectcalico.org/ipAddrs': '["%(ip)s"]' % { ip: staticIp },
    }) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
        volume.fromPersistentVolumeClaim('jellyfinmedia', 'jellyfinmedia-pvc'),
        volume.fromPersistentVolumeClaim('jellyfinconfig', 'jellyfinconfig-pvc'),
    ]),
}
