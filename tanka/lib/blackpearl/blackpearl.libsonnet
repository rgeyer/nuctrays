local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      statefulSet = k.apps.v1.statefulSet;

{
  new(namespace):: {
    local this = self,

    route_script_cm:
      configMap.new('route-script') +
      configMap.mixin.metadata.withNamespace(namespace) +
      configMap.withData({
        'route-override.sh': importstr './route-override.sh',
      }),

    init_container::
      container.new('vpn-route-init', 'busybox') +
      container.withCommand([
        'bash',
        '-c',
        'cp /vpn/route-override.sh /tmp/route/route-override.sh; chown root:root /tmp/route/route-override.sh; chmod o+x /tmp/route/route-override.sh;'
      ]) +
      container.withVolumeMountsMixin([
        k.core.v1.volumeMount.new('tmp', '/tmp/route'),
        k.core.v1.volumeMount.new('route-script', '/vpn')
      ]),

    statefulset:
      statefulSet.new('black-pearl', 1, this.init_container) +
      statefulSet.mixin.metadata.withNamespace(namespace) +
      k.util.configMapVolumeMount(this.route_script_cm)
  }
}