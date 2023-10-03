local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service,
      volume = k.core.v1.volume;

local traefikingress = import 'traefik/ingress.libsonnet';

{
  cm:
    configMap.new('poraclecfg') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'geofence.json': (importstr './geofence.json'),
      'dts.json': (importstr './dts.json'),
    }),

  container::
    container.new('poracle', $._images.poracle) +
    container.withImagePullPolicy('Always') +
    container.withEnv([
      k.core.v1.envVar.fromSecretRef('SQLUSER', 'poracle-secret', 'username'),
      k.core.v1.envVar.fromSecretRef('SQLPASS', 'poracle-secret', 'password'),
      k.core.v1.envVar.fromSecretRef('DISCORDTOKEN', 'poracle-secret', 'token'),
      k.core.v1.envVar.new('SQLHOST', 'mysql-primary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('SQLDBNAME', 'poracle'),
      k.core.v1.envVar.new('SQLPORT', '3306'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('poracle', 3030),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/config'),
    ]) +
    container.withCommand(['sh', '-c']) +
    container.withArgs([|||
      #!/usr/bin/env sh

      cp /config/geofence.json /usr/src/app/config/
      cp /config/dts.json /usr/src/app/config/

      cat << EOF > /usr/src/app/config/local.json
      {
        "server": {
          "host": "0.0.0.0"
        },
          "database": {
              "client": "mysql",
              "conn": {
                  "host": "${SQLHOST}",
                  "database": "${SQLDBNAME}",
                  "user": "${SQLUSER}",
                  "password": "${SQLPASS}",
                  "port": "${SQLPORT}"
              }
          },
          "pvp": {
              "pvpDisplayMaxRank": 20,
              "pvpFilterMaxRank": 20
          },
          "discord": {
              "enabled": true,
              "token": [
                  "${DISCORDTOKEN}"
              ],
              "channels": [
                  "599064944385982473",
                  "696424210574082139",
                  "730097379067297843",
                  "719755618033860608",
                  "943685071104278578",
                  // SLO PoGo - scanner-chat
                  "948730079805071420",
                  // Peaceful Pogo - tracker-chat
                  "719755618033860608"
              ],
              "userRole": [
                  "730100829868130364",
                  "732041685735047248",
                  "946231354427838504"
              ],
              "admins": [
                  "210982660107927553",
                  "344879003208777728",
                  "688104187099217992",
                  "690950089002188830",
                  "339546140309585923",
                  "470843805965221898",
                  "77928002612101120",
                  "339287808604766209",
                  "407724369700454410",
                  "340212290945286145",
                  "227578396253749248",
                  "339923396630413312"
              ]
          },
          "geocoding": {
              "provider": "nominatim",
              "providerURL": "http://nominatim:8080"
          }
      }
      EOF

      cd /usr/src/app
      npm start
    |||]),

  deployment:
    deployment.new('poracle', 1, $.container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      volume.fromConfigMap('config', 'poraclecfg'),
    ]),

  service:
    k.util.serviceFor($.deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  // This is only here in an attempt to allow cross/cluster comms, but the hostname and reverse proxy don't seem to be working at all..
  ingress:
    traefikingress.newIngressRoute('poracle', $._config.namespace, 'poracle.lsmpogo.com', 'poracle', 3030),
}
