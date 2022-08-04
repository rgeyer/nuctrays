local blackpearl = import 'blackpearl/blackpearl.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local secrets = import 'secrets.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

local k = import 'ksonnet-util/kausal.libsonnet';
local ingress = k.networking.v1.ingress,
      path = k.networking.v1.httpIngressPath,
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


  radarrconfig:
    nfspvc.new(namespace, '192.168.42.10', '/kubestore/plex/radarrconfig', 'radarrconfig'),
  sonarrconfig:
    nfspvc.new(namespace, '192.168.42.10', '/kubestore/plex/sonarrconfig', 'sonarrconfig'),
  lidarrconfig:
    nfspvc.new(namespace, '192.168.42.10', '/kubestore/plex/lidarrconfig', 'lidarrconfig'),
  readarrconfig:
    nfspvc.new(namespace, '192.168.42.10', '/kubestore/plex/readarrconfig', 'readarrconfig'),
  nzbgetconfig:
    nfspvc.new(namespace, '192.168.42.10', '/kubestore/plex/nzbgetconfig', 'nzbgetconfig'),
  media:
    nfspvc.new(namespace, '192.168.42.10', '/kubestore/plex/media', 'media'),

  blackpearl:
    blackpearl.new(name, $._config.blackpearl.ovpn_uname, $._config.blackpearl.ovpn_pass) +
    blackpearl.withNamespace(namespace) +
    blackpearl.withPvcs({
      radarrconfig: 'radarrconfig-pvc',
      sonarrconfig: 'sonarrconfig-pvc',
      lidarrconfig: 'lidarrconfig-pvc',
      readarrconfig: 'readarrconfig-pvc',
      nzbgetconfig: 'nzbgetconfig-pvc',
      media: 'media-pvc',
    }),


  radarringress: $.makeIngress('radarr', 'radarr.k3d.localhost', name, 7878),
  sonarringress: $.makeIngress('sonarr', 'sonarr.k3d.localhost', name, 8989),
  lidarringress: $.makeIngress('lidarr', 'lidarr.k3d.localhost', name, 8686),
  readarringress: $.makeIngress('readarr', 'readarr.k3d.localhost', name, 8787),
  nzbgetingress: $.makeIngress('nzbget', 'nzbget.k3d.localhost', name, 6789),
}
