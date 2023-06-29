local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      statefulSet = k.apps.v1.statefulSet,
      secret = k.core.v1.secret,
      service = k.core.v1.service,
      volume = k.core.v1.volume,
      volMnt = k.core.v1.volumeMount;

{
  withNamespace(namespace):: {
    ovpn_config_secret+: secret.mixin.metadata.withNamespace(namespace),
    ovpn_auth_secret+: secret.mixin.metadata.withNamespace(namespace),
    route_script_cm+: configMap.mixin.metadata.withNamespace(namespace),    
    statefulset+: statefulSet.mixin.metadata.withNamespace(namespace),
    service+: service.mixin.metadata.withNamespace(namespace),
  },

  withPvc(name, pvc):: {
    pvcs+:: {
      [name]: pvc
    },
  },

  withPvcs(pvcs):: {
    pvcs+:: pvcs,
  },

  new(name, ovpn_uname, ovpn_pass):: {
    local this = self,

    common_envvars:: [{
      name: 'TZ',
      value: 'America/Los_Angeles',
    }],

    pvcs:: {
      [pvc]: error 'no %s pvc provided' % pvc
      for pvc in [
        'radarrconfig',
        'sonarrconfig',
        'lidarrconfig',
        'readarrconfig',
        'nzbgetconfig',
        'media',
      ]
    },

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
      container.withArgsMixin([|||
        beforeip=$(curl ifconfig.me)
        echo "Internet IP before VPN is ${beforeip}"
        openvpn --config 'vpn/client.ovpn' --auth-user-pass 'vpn/auth.txt' --script-security 3 --route-up /tmp/route/route-override.sh --writepid /var/run/openvpn.pid --log /var/log/openvpn --daemon

        until [ -f /var/run/openvpn.complete ]
        do
          sleep 3
        done
        sleep 3 # One more time, just to make sure openvpn is totally ready to go
        rm -rf /var/run/openvpn.complete # Delete this incase we reboot or fail
        afterip=$(curl ifconfig.me)
        echo "Internet IP after VPN is ${afterip}"

        if [[ "${beforeip}" == "${afterip}" ]]; then
          echo "VPN didn't seem to initialize or routes didn't apply. This pod is still using the non VPN internet IP"
          exit 1
        fi
        tail -f /var/log/openvpn
      |||]) +
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
        volMnt.new('media', '/media'),
      ]) +
      container.withPorts([
        containerPort.newNamed(name='http', containerPort=7878),
      ]),

    sonarr_container::
      container.new('sonarr', 'hotio/sonarr:phantom') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('sonarrconfig', '/config'),
        volMnt.new('media', '/media'),
      ]) +
      container.withPorts([
        containerPort.newNamed(name='http', containerPort=8989),
      ]),

    lidarr_container::
      container.new('lidarr', 'hotio/lidarr') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('lidarrconfig', '/config'),
        volMnt.new('media', '/media'),
      ]) +
      container.withPorts([
        containerPort.newNamed(name='http', containerPort=8686),
      ]),

    readarr_container::
      container.new('readarr', 'hotio/readarr:nightly-0.1.0.619') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('readarrconfig', '/config'),
        volMnt.new('media', '/media'),
      ]) +
      container.withPorts([
        containerPort.newNamed(name='http', containerPort=8787),
      ]),

    nzbget_container::
      container.new('nzbget', 'hotio/nzbget') +
      container.withEnv(this.common_envvars) +
      container.withVolumeMountsMixin([
        volMnt.new('nzbgetconfig', '/config'),
        volMnt.new('media', '/media'),
      ]) +
      container.withPorts([
        containerPort.newNamed(name='http', containerPort=6789),
      ]),
      
    overseerr_container::
      container.new('overseerr', 'lscr.io/linuxserver/overseerr:latest') +
      container.withPorts([
        containerPort.new('overseerr', 5055),
      ]) +
      container.withVolumeMountsMixin([
        volMnt.new('overseerrconfig', '/config'),
        volMnt.new('media', '/media'),
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
      configMap.withData({
        'route-override.sh': importstr './route-override.sh',
      }),

    statefulset:
      statefulSet.new(name, 1, {}) +
      statefulSet.spec.withServiceName(name) +
      statefulSet.spec.template.spec.withContainers([
        this.vpn_container, 
        this.radarr_container,
        this.sonarr_container,
        this.lidarr_container,
        this.readarr_container,
        this.nzbget_container,
        this.overseerr_container
      ]) +
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
        volume.fromPersistentVolumeClaim('radarrconfig', this.pvcs['radarrconfig']),
        volume.fromPersistentVolumeClaim('sonarrconfig', this.pvcs['sonarrconfig']),
        volume.fromPersistentVolumeClaim('lidarrconfig', this.pvcs['lidarrconfig']),
        volume.fromPersistentVolumeClaim('readarrconfig', this.pvcs['readarrconfig']),
        volume.fromPersistentVolumeClaim('nzbgetconfig', this.pvcs['nzbgetconfig']),
        volume.fromPersistentVolumeClaim('overseerrconfig', this.pvcs['overseerrconfig']),
        volume.fromPersistentVolumeClaim('media', this.pvcs['media']),
      ]) +
      // k.util.pvcVolumeMount(this.pvcs['media'], '/media', false) +
      statefulSet.spec.template.spec.withDnsPolicy('ClusterFirst') +
      statefulSet.spec.template.spec.dnsConfig.withNameservers(['1.1.1.1', '8.8.8.8', '8.8.4.4'],),    

    service:
      k.util.serviceFor(this.statefulset),
  }
}