local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local prom = import '0.57/main.libsonnet';
local sm = prom.monitoring.v1.serviceMonitor;

{
  certman: helm.template('certman', '../../../charts/cert-manager', {
    namespace: 'sharedsvc',
    values: {      
    },
    installCrds: true,
    kubeVersion: 'v1.24.3',
    noHooks: true,
  }),

  certmanServiceMonitor:
    sm.new('cert-manager') +
    sm.metadata.withLabels({instance: 'primary-me'}) +
    sm.spec.selector.withMatchLabels({ app_kubernetes_io_name: 'cert-manager'}) +
    sm.spec.withEndpoints([
      sm.spec.endpoints.withHonorLabels(true) +
      sm.spec.endpoints.withRelabelings([
        sm.spec.endpoints.relabelings.withAction('replace') +
        sm.spec.endpoints.relabelings.withTargetLabel('job') +
        sm.spec.endpoints.relabelings.withReplacement('integrations/cert-manager')
      ]),
    ]),
}