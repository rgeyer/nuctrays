local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      secret = k.core.v1.secret,
      service = k.core.v1.service;

local traefikingress = import 'traefik/ingress.libsonnet';

local secrets = import 'secrets.libsonnet';

local namespace = 'sharedsvc';

secrets {
  wikijs_secret:
    secret.new('wikijs', {}) +
    secret.withStringData({
      MYSQL_USER: $._config.wikijs.mysql_user,
      MYSQL_PASS: $._config.wikijs.mysql_pass,
    }) +
    secret.mixin.metadata.withNamespace(namespace),

  container::
    container.new('wikijs', 'ghcr.io/requarks/wiki:2') +
    container.withEnv([
      k.core.v1.envVar.new('DB_TYPE', 'mysql'),
      k.core.v1.envVar.new('DB_HOST', 'mysql-primary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('DB_PORT', '3306'),
      k.core.v1.envVar.new('DB_NAME', 'wikijs'),
      k.core.v1.envVar.fromSecretRef('DB_USER', 'wikijs', 'MYSQL_USER'),
      k.core.v1.envVar.fromSecretRef('DB_PASS', 'wikijs', 'MYSQL_PASS'),
    ]) +
    container.withPorts([
      containerPort.new('wikijs', 3000),
    ]),

  deployment:
    deployment.new('wikijs', 1, $.container) +
    deployment.mixin.metadata.withNamespace(namespace),

  service:
    k.util.serviceFor($.deployment) +
    service.mixin.metadata.withNamespace(namespace),

  ingress:
    traefikingress.newIngressRoute('wiki', namespace, 'wiki.ryangeyer.com', 'wikijs', 3000, true),
}
