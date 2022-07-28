local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      configMap = k.core.v1.configMap;

{
  new(image, namespace, oneip, twoip):: {
    local this = self,
    dnsmasq_container::
      container.new('dnsmasq', image) +
      container.withArgs(['-C', '/etc/dnsmasq.d/dnsmasq.conf', '-d']) +
      container.livenessProbe.exec.withCommand([
        '/usr/bin/nslookup',
        'map.lsmpogo.com',
        '127.0.0.1',
      ]),

    dnsmasq_cm:
      configMap.new('dnsmasq-config') +
      configMap.mixin.metadata.withNamespace(namespace) +
      configMap.withData({
        'dnsmasq.conf': importstr './dnsmasq.conf',
      }),

    dnsmasq1_deployment:
      deployment.new('dnsmasq1', 1, this.dnsmasq_container) +
      deployment.mixin.metadata.withNamespace(namespace) +
      deployment.spec.template.metadata.withAnnotations({
        'cni.projectcalico.org/ipAddrs': '["%s"]' % oneip,
      }) +
      deployment.spec.strategy.withType('Recreate') +
      k.util.configMapVolumeMount(this.dnsmasq_cm, '/etc/dnsmasq.d'),

    dnsmasq2_deployment:
      deployment.new('dnsmasq2', 1, this.dnsmasq_container) +
      deployment.mixin.metadata.withNamespace(namespace) +
      deployment.spec.template.metadata.withAnnotations({
        'cni.projectcalico.org/ipAddrs': '["%s"]' % twoip,
      }) +
      deployment.spec.strategy.withType('Recreate') +
      deployment.spec.template.spec.affinity.podAntiAffinity.withRequiredDuringSchedulingIgnoredDuringExecution([
        {
          labelSelector: {
            matchExpressions: [
              {
                key: 'name',
                operator: 'In',
                values: ['dnsmasq1'],
              },
            ],
          },
          topologyKey: 'kubernetes.io/hostname',
        },
      ]) +
      k.util.configMapVolumeMount(this.dnsmasq_cm, '/etc/dnsmasq.d'),
  },
}
