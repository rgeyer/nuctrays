local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      statefulSet = k.apps.v1.statefulSet,
      secret = k.core.v1.secret;

{
  new(namespace):: {
    local this = self,

    common_envvars:: {
      'TZ': 'America/Los_Angeles',
    },

    init_container::
      container.new('vpn-route-init', 'busybox') +
      container.withEnv(this.common_envvars) +
      container.withCommand([
        'bash',
        '-c',
        'cp /vpn/route-override.sh /tmp/route/route-override.sh; chown root:root /tmp/route/route-override.sh; chmod o+x /tmp/route/route-override.sh;'
      ]) +
      container.withVolumeMountsMixin([
        k.core.v1.volumeMount.new('tmp', '/tmp/route'),
        k.core.v1.volumeMount.new('route-script', '/vpn')
      ]),

    vpn_container::
      container.new('vpn', 'dperson/openvpn-client') +
      container.withEnv(this.common_envvars) +
      container.withCommand([
        'bin/sh',
        '-c'
      ]) +
      container.withArgsMixin([
        "openvpn --config 'vpn/client.ovpn' --auth-user-pass 'vpn/auth.txt' --script-security 3 --route-up /tmp/route/route-override.sh;"
      ]),

    ovpn_config_secret:
      secret.new('ovpn-config', {}) +
      secret.withStringData({
        'client.ovpn': importstr './client.ovpn',
      },),

    ovpn_auth_secret:
      secret.new('ovpn-auth', {}) +
      secret.withStringData({
        'auth.txt': '%(uname)s\n%(pass)s' % {uname: 'foo', pass: 'bar'},
      },),

    route_script_cm:
      configMap.new('route-script') +
      configMap.mixin.metadata.withNamespace(namespace) +
      configMap.withData({
        'route-override.sh': importstr './route-override.sh',
      }),

    statefulset:
      statefulSet.new('black-pearl', 1, this.vpn_container) +
      statefulSet.mixin.metadata.withNamespace(namespace) +
      statefulSet.spec.template.spec.withInitContainers(this.init_container),
      // k.util.configMapVolumeMount(this.route_script_cm, '/vpn')
  }
}