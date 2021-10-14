local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      volumeMount = k.core.v1.volumeMount,
      deployment = k.apps.v1.deployment,
      volume = k.core.v1.volume,
      service = k.core.v1.service;

{
  new(namespace='', pvcName='', s3_rules_host='', s3_rules_bucket=''):: {
    local this = self,

    _images:: {
      cortex: 'cortexproject/cortex:v1.9.0',
    },

    _config:: (import './cortex-config.libsonnet') + {
      s3_rules_host:: s3_rules_host,
      s3_rules_bucket:: s3_rules_bucket,
    },

    // TODO: This should technically be a secret now that it contains minio creds
    configMap:
      configMap.new('cortex-config') +
      configMap.mixin.metadata.withNamespace(namespace) +
      configMap.withData({
        'config.yaml': k.util.manifestYaml(this._config),
      }),

    container::
      container.new('cortex', this._images.cortex) +
      container.withPorts([
        containerPort.newNamed(name='http-metrics', containerPort=80),
        containerPort.newNamed(name='grpc', containerPort=9095),
      ]) +
      container.withArgsMixin(
        k.util.mapToFlags({
          'config.file': '/etc/cortex/config.yaml',
        }),
      ) +
      if pvcName == '' then {} else container.withVolumeMountsMixin(
        volumeMount.new('cortex-data', '/tmp/cortex',)
      ),

    deployment:
      deployment.new('cortex', 1, [this.container]) +
      deployment.mixin.metadata.withNamespace(namespace) +
      k.util.configMapVolumeMount(this.configMap, '/etc/cortex') +
      if pvcName == '' then {} else deployment.mixin.spec.template.spec.withVolumesMixin(
        volume.fromPersistentVolumeClaim('cortex-data', pvcName),
      ),

    service:
      k.util.serviceFor(this.deployment) +
      service.mixin.metadata.withNamespace(namespace)
  },
}
