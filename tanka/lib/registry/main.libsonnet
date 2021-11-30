local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      volumeMount = k.core.v1.volumeMount,
      statefulSet = k.apps.v1.statefulSet,
      volume = k.core.v1.volume,
      service = k.core.v1.service;

local traefikingress = import 'traefik/ingress.libsonnet';

{
  new(namespace='', pvcName=''):: {
    local this = self,

    _images:: {
      registry: 'registry:2',
    },

    container::
      container.new('registry', this._images.registry) +
      container.withPorts([
        containerPort.new('http', 5000),
      ]) +
      if pvcName == '' then {} else container.withVolumeMountsMixin(
        volumeMount.new('registry-data', '/var/lib/registry',)
      ),

    statefulset:
      statefulSet.new('registry', 1, [this.container]) +
      statefulSet.spec.withServiceName('registry') +
      statefulSet.mixin.metadata.withNamespace(namespace) +
      if pvcName == '' then {} else statefulSet.mixin.spec.template.spec.withVolumesMixin(
        volume.fromPersistentVolumeClaim('registry-data', pvcName),
      ),

    service:
      k.util.serviceFor(this.statefulset) +
      service.mixin.metadata.withNamespace(namespace),

    ingress: traefikingress.newIngressRoute(
      'registry', 
      namespace, 
      'registry.ryangeyer.com', 
      'registry', 
      5000, 
      false, 
      true),
  },
}
