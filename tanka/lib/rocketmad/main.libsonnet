local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      service = k.core.v1.service,
      statefulSet = k.apps.v1.statefulSet;

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

{
  perstore:
    nfspvc.new($._config.namespace, $._config.rocketmad.pvc.nfsHost, $._config.rocketmad.pvc.nfsPath, 'rocketmadassets'),

  cm:
    configMap.new('rocketmad') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'config.ini': |||
        pogo-assets: /PokeMinersAssets/pogo_assets
        generate-images
      |||
    }),

  container::
    container.new('rocketmad', $._images.rocketmap) +
    container.withImagePullPolicy('Always') +
    container.withEnv([
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),  
      k.core.v1.envVar.fromSecretRef('SQLPASS', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
      k.core.v1.envVar.fromSecretRef('SQLUSER', $._config.madmysql.secretname, $._config.madmysql.secretuserkey),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('rocketmad', 5000),
    ]) +
    container.withArgs([
      '-l', 'Lompoc, CA',
      '--db-host', $._config.rocketmap.dbhost,
      '--db-name', $._config.rocketmap.dbname,
      '--db-user', '$(SQLUSER)',
      '--db-pass', '$(SQLPASS)',
      '-gen',
      '-pa', '/PokeMinerAssets/pogo_assets',
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('rocketmadassets', '/PokeMinerAssets'),
      k.core.v1.volumeMount.new('config', '/usr/src/app/config'),
    ]),

  initContainer::
    container.new('pokeminerassets', $._images.git) +
    container.withCommand(['/bin/sh', '-c']) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('rocketmadassets', '/PokeMinersAssets'),
    ]) +
    container.withArgs([|||
      #!/usr/bin/env sh

      [[ -d /PokeMinersAssets/pogo_assets ]] || git clone https://github.com/PokeMiners/pogo_assets /PokeMinersAssets/pogo_assets
      cd /PokeMinersAssets/pogo_assets
      git pull
    |||]),

  statefulset:
    statefulSet.new('rocketmad', 1, $.container) +
    statefulSet.spec.withServiceName('rocketmad') +
    statefulSet.mixin.metadata.withNamespace($._config.namespace) +
    statefulSet.spec.template.spec.withInitContainers($.initContainer) +
    statefulSet.spec.template.spec.withVolumes([
      k.core.v1.volume.fromConfigMap('config', 'rocketmad'),
      k.core.v1.volume.fromPersistentVolumeClaim('rocketmadassets', 'rocketmadassets-pvc'),
    ]),

  service:
    k.util.serviceFor($.statefulset) +
    service.mixin.metadata.withNamespace($._config.namespace),

  ingress:
    traefikingress.newIngressRoute('rocketmad', $._config.namespace, 'map.lsmpogo.com', 'rocketmad', 5000, true),
}