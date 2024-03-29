local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local pv = k.core.v1.persistentVolume,
      pvc = k.core.v1.persistentVolumeClaim,
      statefulSet = k.apps.v1.statefulSet;

local blackpearl = import 'blackpearl/blackpearl.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local secrets = import 'secrets.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';
local speedtest = import 'speedtest/main.libsonnet';

local prom = import '0.57/main.libsonnet';
local sm = prom.monitoring.v1.serviceMonitor;

local namespace = 'sharedsvc';
local name = 'blackpearl';

secrets {
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
      radarrconfig: 'radarrconfig-pvc',
      sonarrconfig: 'sonarrconfig-pvc',
      lidarrconfig: 'lidarrconfig-pvc',
      readarrconfig: 'readarrconfig-pvc',
      nzbgetconfig: 'nzbgetconfig-pvc',
      overseerrconfig: 'overseerrconfig-pvc',
      media: 'media-pvc',
    }) +
    {
      statefulset+:
        statefulSet.spec.template.spec.withNodeName('thinkcentre2') +
        statefulSet.spec.template.spec.withContainersMixin(speedtest.newContainer().container),
    },

  radarringress: traefikingress.newIngressRoute('radarr', namespace, 'radarr.ryangeyer.com', name, 7878),
  sonarringress: traefikingress.newIngressRoute('sonarr', namespace, 'sonarr.ryangeyer.com', name, 8989),
  lidarringress: traefikingress.newIngressRoute('lidarr', namespace, 'lidarr.ryangeyer.com', name, 8686),
  readarringress: traefikingress.newIngressRoute('readarr', namespace, 'readarr.ryangeyer.com', name, 8787),
  nzbgetingress: traefikingress.newIngressRoute('nzbget', namespace, 'nzbget.ryangeyer.com', name, 6789),
  overseerringress: traefikingress.newIngressRoute('overseerr', namespace, 'overseerr.ryangeyer.com', name, 5055),

  vpnSpeedtestPodMonitor:
    sm.new('speedtest-vpn') +
    sm.metadata.withLabels({ instance: 'primary-me' }) +
    sm.spec.selector.withMatchLabels({ name: 'blackpearl' }) +
    sm.spec.namespaceSelector.withMatchNames([namespace]) +
    sm.spec.withEndpoints([
      sm.spec.endpoints.withHonorLabels(true) +
      sm.spec.endpoints.withPort('speedtest-http') +
      sm.spec.endpoints.withPath('/probe') +
      sm.spec.endpoints.withInterval('10m') +
      sm.spec.endpoints.withScrapeTimeout('2m'),
    ]),
}
