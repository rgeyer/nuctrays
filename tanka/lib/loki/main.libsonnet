local k = import 'ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount;

{
  new(namespace='', pvcName=''):: {
    local this = self,

    configMap:
      configMap.new('loki-config') +
      configMap.mixin.metadata.withNamespace(namespace) +
      configMap.withData({
        'config.yaml': importstr './loki-config.yml',
      }),

    container::
      container.new('loki', 'grafana/loki:2.3.0') +
      container.withPorts([
        containerPort.newNamed(name='http', containerPort=3100),
        containerPort.newNamed(name='grpc', containerPort=9095),
      ]) +
      container.withArgsMixin(
        k.util.mapToFlags({
          'config.file': '/etc/loki/config.yaml',
        }),
      ) +
      if pvcName == '' then {} else container.withVolumeMountsMixin(
        volumeMount.new('loki-data', '/tmp/loki')
      ),

    deployment:
      deployment.new('loki', 1, [this.container]) +
      deployment.mixin.metadata.withNamespace(namespace) +
      k.util.configMapVolumeMount(this.configMap, '/etc/loki') +
      if pvcName == '' then {} else deployment.mixin.spec.template.spec.withVolumesMixin(
        volume.fromPersistentVolumeClaim('loki-data', pvcName),
      ),

    service:
      k.util.serviceFor(this.deployment) +
      service.mixin.metadata.withNamespace(namespace),
  },
}
