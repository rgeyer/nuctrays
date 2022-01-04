local k = import 'ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount;

{
  new(namespace='default', key='', secret='', pvcName=''):: {
    local this = self,
    minio_container::
      container.new('minio', 'minio/minio:RELEASE.2021-12-29T06-49-06Z') +
      container.withPorts(
        [
          containerPort.new('api', 9000),
          containerPort.new('console', 9001),
        ],
      ) +
      // TODO: The key and secret should be actually *in* a secret, and brought in
      // with an envfrom
      container.withEnvMixin([
        {
          name: 'MINIO_ACCESS_KEY',
          value: key,
        },
        {
          name: 'MINIO_SECRET_KEY',
          value: secret,
        },
        {
          name: 'MINIO_PROMETHEUS_AUTH_TYPE',
          value: 'public',
        },
        {
          name: 'CONSOLE_SECURE_TLS_REDIRECT',
          value: 'false',
        },
        {
          name: 'MINIO_BROWSER_REDIRECT_URL',
          value: 'https://minio.ryangeyer.com',
        },
      ]) + container.withCommand(
        ['/bin/bash', '-c']
      ) + container.withArgs(
        // Create the /data/cortex folder to bootstrap cortex ruler
        ['mkdir -p /data/cortex && mkdir -p /data/cortexblocks && /opt/bin/minio server /data --console-address :9001']
      ) +
      if pvcName == '' then {} else container.withVolumeMountsMixin(
          volumeMount.new('minio-data', '/data')
      ),

    minio_deployment:
      deployment.new('minio', 1, this.minio_container) +
      deployment.mixin.metadata.withNamespace(namespace) +
      if pvcName == '' then {} else deployment.mixin.spec.template.spec.withVolumesMixin(
          volume.fromPersistentVolumeClaim('minio-data', pvcName)
      ),

    minio_service:
      k.util.serviceFor(this.minio_deployment) +
      service.mixin.metadata.withNamespace(namespace),
  },
}