local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      statefulSet = k.apps.v1.statefulSet,
      secret = k.core.v1.secret,
      volume = k.core.v1.volume,
      volMnt = k.core.v1.volumeMount;

{
  new(namespace, ovpn_uname, ovpn_pass):: {
    local this = self,

    common_envvars:: [{
      name: 'TZ',
      value: 'America/Los_Angeles',
    }],

    init_container::
      container.new('vpn-route-init', 'busybox') +
      container.withEnv(this.common_envvars) +
      container.withCommand([
        '/bin/sh',
        '-c',
        'cp /vpn/route-override.sh /tmp/route/route-override.sh; chown root:root /tmp/route/route-override.sh; chmod o+x /tmp/route/route-override.sh;'
      ]) +
      container.withVolumeMountsMixin([
        volMnt.new('tmp', '/tmp/route'),
        volMnt.new('route-script', '/vpn')
      ]),

    vpn_container::
      container.new('vpn', 'dperson/openvpn-client') +
      container.withEnv(this.common_envvars) +
      container.withCommand([
        '/bin/sh',
        '-c'
      ]) +
      container.withArgsMixin([
        "openvpn --config 'vpn/client.ovpn' --auth-user-pass 'vpn/auth.txt' --script-security 3 --route-up /tmp/route/route-override.sh;"
      ]) +
      container.securityContext.withPrivileged(true) +
      container.securityContext.capabilities.withAdd('NET_ADMIN') +
      container.withVolumeMountsMixin([        
        volMnt.new('tmp', '/tmp/route'),
        volMnt.new('ovpn-config', '/vpn/client.ovpn') + volMnt.withSubPath('client.ovpn'),
        volMnt.new('ovpn-auth', '/vpn/auth.txt') + volMnt.withSubPath('auth.txt'),
      ],),

    radarr_container::
      container.new('radarr', 'hotio/radarr') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('radarrconfig', '/config'),
      ]),

    sonarr_container::
      container.new('sonarr', 'hotio/sonarr:phantom') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('sonarrconfig', '/config'),
      ]),

    lidarr_container::
      container.new('lidarr', 'hotio/lidarr') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('lidarrconfig', '/config'),
      ]),      

    readarr_container::
      container.new('readarr', 'hotio/readarr:nightly-0.1.0.619') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('readarrconfig', '/config'),
      ]),

    nzbget_container::
      container.new('nzbget', 'hotio/nzbget') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('nzbgetconfig', '/config'),
      ]),

    ovpn_config_secret:
      secret.new('ovpn-config', {}) +
      secret.withStringData({
        'client.ovpn': importstr './client.ovpn',
      },),

    ovpn_auth_secret:
      secret.new('ovpn-auth', {}) +
      secret.withStringData({
        'auth.txt': '%(uname)s\n%(pass)s' % {uname: ovpn_uname, pass: ovpn_pass},
      },),

    route_script_cm:
      configMap.new('route-script') +
      configMap.mixin.metadata.withNamespace(namespace) +
      configMap.withData({
        'route-override.sh': importstr './route-override.sh',
      }),

    statefulset:
      statefulSet.new('black-pearl-too', 1, {}) +
      statefulSet.spec.withServiceName('black-pearl') +
      statefulSet.spec.template.spec.withContainers([
        this.vpn_container, 
        this.radarr_container,
        this.sonarr_container,
        this.lidarr_container,
        this.readarr_container,
        this.nzbget_container,]) +
      statefulSet.mixin.metadata.withNamespace(namespace) +
      statefulSet.spec.template.spec.withInitContainers(this.init_container) +
      statefulSet.spec.template.spec.withVolumes([
        volume.fromConfigMap('route-script','route-script',
          [{key: 'route-override.sh', path: 'route-override.sh'}]) +
          volume.configMap.withDefaultMode(420),
        volume.fromSecret('ovpn-config', 'ovpn-config') +
          volume.secret.withItems([{key: 'client.ovpn', path: 'client.ovpn'}]) + 
          volume.secret.withDefaultMode(420),
        volume.fromSecret('ovpn-auth', 'ovpn-auth') +
          volume.secret.withItems([{key: 'auth.txt', path: 'auth.txt'}]) +
          volume.secret.withDefaultMode(420),
        volume.fromEmptyDir('tmp'),
        volume.fromPersistentVolumeClaim('radarrconfig', 'radarrconfig'),
        volume.fromPersistentVolumeClaim('sonarrconfig', 'sonarrconfig'),
        volume.fromPersistentVolumeClaim('lidarrconfig', 'lidarrconfig'),
        volume.fromPersistentVolumeClaim('readarrconfig', 'readarrconfig'),
        volume.fromPersistentVolumeClaim('nzbgetconfig', 'nzbgetconfig'),
        volume.fromPersistentVolumeClaim('plexmedia', 'plexmedia'),
      ]) +
      k.util.pvcVolumeMount('plexmedia', '/media', false) +
      statefulSet.spec.template.spec.withDnsPolicy('ClusterFirst') +
      statefulSet.spec.template.spec.dnsConfig.withNameservers(['1.1.1.1', '8.8.8.8', '8.8.4.4'],),
  }
}