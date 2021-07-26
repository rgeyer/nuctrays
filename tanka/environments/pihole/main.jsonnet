local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      configMap = k.core.v1.configMap;

{
  _images+:: {
    pihole: 'pihole/pihole:v5.8',
    dnsmasq: 'strm/dnsmasq:latest',
  },

  _config+:: {
    namespace: 'pihole',
  },

  namespace: k.core.v1.namespace.new($._config.namespace),

  pihole_container::
    container.new('pihole', $._images.pihole),

  dnsmasq_container::
    container.new('dnsmasq', $._images.dnsmasq) +
    container.withArgs(['-C', '/etc/dnsmasq.d/dnsmasq.conf', '-d']),

  dnsmasq_cm:
    configMap.new('dnsmasq-config') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'dnsmasq.conf': importstr './dnsmasq.conf',
    }),

  dnsmasq_deployment:
    deployment.new('dnsmasq', 1, $.dnsmasq_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    k.util.configMapVolumeMount($.dnsmasq_cm, '/etc/dnsmasq.d'),
}
