local blackpearl = import 'blackpearl/blackpearl.libsonnet';
local secrets = import 'secrets.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local namespace = 'sharedsvc';
local name = 'blackpearl';

secrets {
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

  radarringress: traefikingress.newIngressRoute('radarr', namespace, 'radarr.ryangeyer.com', name, 7878),
  sonarringress: traefikingress.newIngressRoute('sonarr', namespace, 'sonarr.ryangeyer.com', name, 8989),
  lidarringress: traefikingress.newIngressRoute('lidarr', namespace, 'lidarr.ryangeyer.com', name, 8686),
  readarringress: traefikingress.newIngressRoute('readarr', namespace, 'readarr.ryangeyer.com', name, 8787),
  nzbgetingress: traefikingress.newIngressRoute('nzbget', namespace, 'nzbget.ryangeyer.com', name, 6789),
}
