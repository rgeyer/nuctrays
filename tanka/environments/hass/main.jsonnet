local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount,
      statefulSet = k.apps.v1.statefulSet,
      secret = k.core.v1.secret,
      service = k.core.v1.service;

local staticIp = '10.42.0.20';
local namespace = 'hass';

config + secrets {
  mqtttls_pvc: nfspvc.new(
    namespace,
    $._config.mqtt.pvc.nfsHost,
    $._config.mqtt.pvc.nfsPath,
    'mqtttls',
  ),

  secret:
    secret.new('mqttpasswd', {}) +
    secret.withStringData({
      'passwd': $._config.mqtt.passwd,
    }) +
    secret.mixin.metadata.withNamespace(namespace),

  configmap:
    configMap.new('mqttcfg') +
    configMap.mixin.metadata.withNamespace(namespace) +
    configMap.withData({
      'mosquitto.conf': importstr './mosquitto.conf'
    }),

  initcontainer::
    container.new('mqttinit', 'busybox') +
    container.withVolumeMountsMixin([
      volumeMount.new('mqttemptydir', '/mosquitto/config'),
      volumeMount.new('mqttcfg', '/rosquitto/config'),
      volumeMount.new('mqttsecret', '/rosquitto/secret'),
    ]) +
    container.withCommand([
      '/bin/sh',
      '-c',
      'cp /rosquitto/secret/* /mosquitto/config/ && cp /rosquitto/config/* /mosquitto/config/'
    ]),

  container::
    container.new('mqtt', 'eclipse-mosquitto:latest') +
    container.withPorts([
      containerPort.new('mqttinsecure', 1883),
      containerPort.new('mqtt', 8883),
      containerPort.new('mqttws', 8083),
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('mqtttls', '/mosquitto/tls'),
      volumeMount.new('mqttemptydir', '/mosquitto/config')
    ]),

  statefulset:
    statefulSet.new('mqtt', 1, $.container) +
    statefulSet.spec.withServiceName('mqtt') +
    statefulSet.mixin.metadata.withNamespace(namespace) +
    statefulSet.spec.template.metadata.withAnnotations({
      'cni.projectcalico.org/ipAddrs': '["%(ip)s"]' % { ip: staticIp },
    }) +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromEmptyDir('mqttemptydir'),
      volume.fromPersistentVolumeClaim('mqtttls', 'mqtttls-pvc'),
      volume.fromConfigMap('mqttcfg', 'mqttcfg'),
      volume.fromSecret('mqttsecret', 'mqttpasswd')
    ]) +
    statefulSet.spec.template.spec.withInitContainers([$.initcontainer]),

  service:
    k.util.serviceFor($.statefulset) +
    service.mixin.metadata.withNamespace(namespace),

  exporter_container::
    container.new('mqtt-exporter', 'sapcc/mosquitto-exporter:0.6.0') +
    container.withPorts([
      containerPort.new('http-metrics', 9234)
    ]) +
    container.withEnvMap({
      BROKER_ENDPOINT: 'tcp://mqtt:1883',
    }),

  deployment:
    deployment.new('mqtt-exporter', 1, $.exporter_container) +
    deployment.mixin.metadata.withNamespace(namespace),
}
