local blackpearl = import 'blackpearl/blackpearl.libsonnet';
local secrets = import 'secrets.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';
local namespace='plex';
local name='black-pearl-too';

secrets {
  blackpearl: blackpearl.new(name, namespace, $._config.blackpearl.ovpn_uname, $._config.blackpearl.ovpn_pass),
  radarringress: traefikingress.newIngressRoute('radarr', namespace, 'radarr.ryangeyer.com', name, 7878),
  sonarringress: traefikingress.newIngressRoute('sonarr', namespace, 'sonarr.ryangeyer.com', name, 8989),
  lidarringress: traefikingress.newIngressRoute('lidarr', namespace, 'lidarr.ryangeyer.com', name, 8686),
  readarringress: traefikingress.newIngressRoute('readarr', namespace, 'readarr.ryangeyer.com', name, 8787),
  nzbgetingress: traefikingress.newIngressRoute('nzbget', namespace, 'nzbget.ryangeyer.com', name, 6789),
}
