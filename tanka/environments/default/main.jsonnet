local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local registry = import 'registry/main.libsonnet';

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local config = import 'config.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment;

config {
  _images+:: {
    traefik: 'traefik:v2.2',
  },

  registry_pvc: nfspvc.new(
    'default',
    $._config.registry.pvc.nfsHost,
    $._config.registry.pvc.nfsPath,
    'registry',
  ),

  registry: registry.new('default', 'registry-pvc'),

  traefik_pvc: nfspvc.new(
    'traefik',
    $._config.traefik.private.pvc.nfsHost,
    $._config.traefik.private.pvc.nfsPath,
    'traefik',
  ),  

  ptraefik_pvc: nfspvc.new(
    'ptraefik',
    $._config.traefik.public.pvc.nfsHost,
    $._config.traefik.public.pvc.nfsPath,
    'ptraefik',
  ),

  //  TODO: WIP, need to create the secret, and the service account and cluster role binding, plus CRDs. Maybe we'll just import the defaults from the standard traefik deployment

  // traefik_container::
  //   container.new('traefik', $._images.traefik) +
  //   container.withEnvFrom(envFrom.secretRef.withName('certbot-route53')) +
  //   container.withArgsMixin([
  //     '--api.dashboard=true',
  //     '--entrypoints.web.Address=:80',
  //     '--entrypoints.websecure.Address=:443',
  //     '--providers.kubernetescrd',
  //     '--certificatesresolvers.mydnschallenge.acme.dnschallenge=true',
  //     '--certificatesresolvers.mydnschallenge.acme.dnschallenge.provider=route53',
  //     '--certificatesresolvers.mydnschallenge.acme.email=qwikrex@gmail.com',
  //     '--certificatesresolvers.mydnschallenge.acme.storage=/etc/traefik/acme/acme.json',
  //     '--metrics.prometheus=true',
  //     '--metrics.prometheus.addEntryPointsLabels=true',
  //     '--metrics.prometheus.addServicesLabels=true'
  //   ]) +
  //   container.withVolumeMountsMixin([
  //     k.core.v1.volume.fromPersistentVolumeClaim('traefik', 'traefik-pvc'),
  //   ])
}
