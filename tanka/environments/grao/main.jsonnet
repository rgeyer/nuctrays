local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local parseYaml = std.native('parseYaml');

local namespace = 'grao';

{
  namespace: k.core.v1.namespace.new(namespace),

  grafana_agent_operator: helm.template('grafana-agent-operator', '../../charts/grafana-agent-operator', {
    namespace: namespace,
    includeCrds: true
  }),
}
