local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local secret = k.core.v1.secret;

local prom = import '0.57/main.libsonnet';
local sm = prom.monitoring.v1.serviceMonitor;

local cm = (import '1.11/main.libsonnet').nogroup;

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

config + secrets {  

  _config+:: {
    namespace: 'sharedsvc',
  },

  certman: helm.template('certman', '../../../charts/cert-manager', {
    namespace: $._config.namespace,
    values: {
      installCRDs: true,
    },
    kubeVersion: 'v1.24.3',
    noHooks: true,
  }),

  certman_secret:
    secret.new('certman-route53', {}) +
    secret.withStringData({
      AWS_ACCESS_KEY_ID: $._config.certbot.access_key_id,
      AWS_SECRET_ACCESS_KEY: $._config.certbot.secret_access_key,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  certmanServiceMonitor:
    sm.new('cert-manager') +
    sm.metadata.withLabels({ instance: 'primary-me' }) +
    sm.spec.selector.withMatchLabels({ app_kubernetes_io_name: 'cert-manager' }) +
    sm.spec.withEndpoints([
      sm.spec.endpoints.withHonorLabels(true) +
      sm.spec.endpoints.withRelabelings([
        sm.spec.endpoints.relabelings.withAction('replace') +
        sm.spec.endpoints.relabelings.withTargetLabel('job') +
        sm.spec.endpoints.relabelings.withReplacement('integrations/cert-manager'),
      ]),
    ]),

  clusterIssuer:
    cm.v1.clusterIssuer.new('route53') +
    cm.v1.clusterIssuer.metadata.withNamespace($._config.namespace) +
    cm.v1.clusterIssuer.spec.acme.withEmail('qwikrex@gmail.com') +
    cm.v1.clusterIssuer.spec.acme.withServer('https://acme-v02.api.letsencrypt.org/directory') +
    cm.v1.clusterIssuer.spec.acme.privateKeySecretRef.withName('letsencrypt') +
    cm.v1.clusterIssuer.spec.acme.withSolvers([
      cm.v1.clusterIssuer.spec.acme.solvers.selector.withDnsZones(['ryangeyer.com', 'lsmpogo.com']) +
      cm.v1.clusterIssuer.spec.acme.solvers.dns01.route53.withRegion('us-east-1') +
      cm.v1.clusterIssuer.spec.acme.solvers.dns01.route53.accessKeyIDSecretRef.withKey('AWS_ACCESS_KEY_ID') +
      cm.v1.clusterIssuer.spec.acme.solvers.dns01.route53.accessKeyIDSecretRef.withName('certman-route53') +
      cm.v1.clusterIssuer.spec.acme.solvers.dns01.route53.secretAccessKeySecretRef.withKey('AWS_SECRET_ACCESS_KEY') +
      cm.v1.clusterIssuer.spec.acme.solvers.dns01.route53.secretAccessKeySecretRef.withName('certman-route53'),
    ]),
}
