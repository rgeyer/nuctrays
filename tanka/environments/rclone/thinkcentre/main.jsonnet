local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local secret = k.core.v1.secret;

local prom = import '0.57/main.libsonnet';
local sm = prom.monitoring.v1.serviceMonitor;

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

config + secrets {

  _config+:: {
    namespace: 'sharedsvc',
  },

  qnap_secret:
    secret.new('rclone-qnap', {}) +
    secret.metadata.withNamespace($._config.namespace) +
    secret.withStringData($._config.qnap.rclone),

  qnap_endpoint:
    k.core.v1.endpoints.new('qnap-nas') +
    k.core.v1.endpoints.metadata.withNamespace($._config.namespace) +
    k.core.v1.endpoints.withSubsets([
      k.core.v1.endpointSubset.withAddresses([{ip: '192.168.1.10'}]) +
      k.core.v1.endpointSubset.withPorts([{ name: 'rclone', port: 5572}]),
    ]),

  qnap_service:
    k.core.v1.service.new('qnap-nas', {}, {}) +
    k.core.v1.service.metadata.withNamespace($._config.namespace) +
    k.core.v1.service.spec.withPorts([{name: 'rclone', port: 5572}]),

  // Grafana Agent Operator Service Monitor
  qnap_sm:
    sm.new('rclone-qnap') +
    sm.metadata.withLabels({ instance: 'primary-me'}) +
    sm.metadata.withNamespace($._config.namespace) +
    sm.spec.selector.withMatchLabels({name: 'qnap-nas'}) +
    sm.spec.namespaceSelector.withMatchNames([$._config.namespace]) +
    sm.spec.withEndpoints([
      sm.spec.endpoints.withPath('/metrics') +
      sm.spec.endpoints.withHonorLabels(true) +
      sm.spec.endpoints.withPort('rclone') +
      sm.spec.endpoints.basicAuth.password.withKey('pass') +
      sm.spec.endpoints.basicAuth.password.withName('rclone-qnap') +
      sm.spec.endpoints.basicAuth.username.withKey('user') +
      sm.spec.endpoints.basicAuth.username.withName('rclone-qnap'),      
    ]),
}
