local k = import 'ksonnet-util/kausal.libsonnet';
local container = k.core.v1.container;
local deployment = k.apps.v1.deployment;
local traefikingress = import 'traefik/ingress.libsonnet';

local secrets = import 'secrets.libsonnet';

secrets {
  container::
    container.new('grafana', 'grafana/grafana') +
    container.withPorts(k.core.v1.containerPort.new('http', 3000)) +
    container.withEnvMap({
      GF_DATABASE_TYPE: 'mysql',
      GF_DATABASE_HOST: 'mysql-primary.sharedsvc.svc.cluster.local',
      GF_DATABASE_NAME: 'legacy_grafana',
      GF_DATABASE_USER: $._config.legacygrafana.dbuser,
      GF_DATABASE_PASSWORD: $._config.legacygrafana.dbpass,
      GF_SECURITY_ADMIN_USER: 'ryan',
      GF_SECURITY_ADMIN_PASSWORD: $._config.legacygrafana.adminpass,
    }),

  deployment:
    deployment.new('legacy-grafana', 1, [$.container]),

  service:
    k.util.serviceFor($.deployment),

  ingress:
    traefikingress.newIngressRoute('legacygrafana', 'o11y', 'legacygrafana.ryangeyer.com', 'legacy-grafana', 3000, false, true),
}
