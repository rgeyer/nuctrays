local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local parseYaml = std.native('parseYaml');

local namespace = 'grao';

{
  namespace: k.core.v1.namespace.new(namespace),

  # CRDs, sadly we have to list all of them manually AFAIKT
  podmonitors_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.coreos.com_podmonitors.yaml'),
  probes_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.coreos.com_probes.yaml'),
  servicemonitors_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.coreos.com_servicemonitors.yaml'),
  grafanaagents_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.grafana.com_grafanaagents.yaml'),
  integrations_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.grafana.com_integrations.yaml'),
  logsinstances_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.grafana.com_logsinstances.yaml'),
  metricsinstances_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.grafana.com_metricsinstances.yaml'),
  podlogs_crd: parseYaml(importstr '../../charts/grafana-agent-operator/crds/monitoring.grafana.com_podlogs.yaml'),

  grafana_agent_operator: helm.template('grafana-agent-operator', '../../charts/grafana-agent-operator', {})
}
