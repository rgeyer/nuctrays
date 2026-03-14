local blackpearl = import 'blackpearl/blackpearl.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local secrets = import 'secrets.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

local k = import 'ksonnet-util/kausal.libsonnet';
local ingress = k.networking.v1.ingress,
      path = k.networking.v1.httpIngressPath,
      pv = k.core.v1.persistentVolume,
      pvc = k.core.v1.persistentVolumeClaim,
      rule = k.networking.v1.ingressRule;

local namespace = 'default';
local name = 'blackpearl';

secrets {
  makeIngress(name, host, svcname, svcport):: {
    ingress:
      ingress.new(name) +
      ingress.mixin.spec.withRules([
        rule.withHost(host) +
        rule.http.withPaths([
          path.withPath('/')
          + path.withPathType('Prefix')
          + path.backend.service.withName(svcname)
          + path.backend.service.port.withNumber(svcport),
        ]),
      ]),
  },

  makeHostPvPair(name, namespace, path):: {
    pv:
      pv.new('%s-pv' % name) +
      pv.spec.withAccessModes('ReadWriteOnce') +
      pv.spec.withCapacity({ storage: '1Gi' }) +
      pv.spec.withStorageClassName('manual') +
      pv.spec.hostPath.withPath(path),

    pvc:
      pvc.new('%s-pvc' % name) +
      pvc.spec.withAccessModes('ReadWriteOnce') +
      pvc.spec.withStorageClassName('manual') +
      pvc.spec.withVolumeName('%s-pv' % name) +
      pvc.spec.resources.withRequests({ storage: '1Gi' }) +
      pvc.mixin.metadata.withNamespace(namespace),
  },

  radarrconfig:
    $.makeHostPvPair('radarrconfig', namespace, '/opt/kubehostpaths/blackpearl/radarrconfig'),
  sonarrconfig:
    $.makeHostPvPair('sonarrconfig', namespace, '/opt/kubehostpaths/blackpearl/sonarrconfig'),
  lidarrconfig:
    $.makeHostPvPair('lidarrconfig', namespace, '/opt/kubehostpaths/blackpearl/lidarrconfig'),
  readarrconfig:
    $.makeHostPvPair('readarrconfig', namespace, '/opt/kubehostpaths/blackpearl/readarrconfig'),
  nzbgetconfig:
    $.makeHostPvPair('nzbgetconfig', namespace, '/opt/kubehostpaths/blackpearl/nzbgetconfig'),
  overseerrconfig:
    $.makeHostPvPair('overseerrconfig', namespace, '/opt/kubehostpaths/blackpearl/overseerr'),
  media:
    nfspvc.new(namespace, '192.168.1.20', '/mnt/ZeroThru5/Media', 'media'),

  blackpearl:
    blackpearl.new(name, $._config.blackpearl.ovpn_uname, $._config.blackpearl.ovpn_pass) +
    blackpearl.withNamespace(namespace) +
    blackpearl.withPvcs({
      radarrconfig: 'radarr-pvc',
      sonarrconfig: 'sonarrconfig-pvc',
      lidarrconfig: 'lidarrconfig-pvc',
      readarrconfig: 'readarrconfig-pvc',
      nzbgetconfig: 'nzbgetconfig-pvc',
      overseerrconfig: 'overseerrconfig-pvc',
      media: 'media-pvc',
    }),


  radarringress: $.makeIngress('radarr', 'radarr.k3d.localhost', name, 7878),
  sonarringress: $.makeIngress('sonarr', 'sonarr.k3d.localhost', name, 8989),
  lidarringress: $.makeIngress('lidarr', 'lidarr.k3d.localhost', name, 8686),
  readarringress: $.makeIngress('readarr', 'readarr.k3d.localhost', name, 8787),
  nzbgetingress: $.makeIngress('nzbget', 'nzbget.k3d.localhost', name, 6789),
  overseerringress: $.makeIngress('overseerr', 'overseerr.k3d.localhost', name, 5055),
}
