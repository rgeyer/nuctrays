local ksm = import 'kube-state-metrics/kube-state-metrics.libsonnet';

local config = import 'config.libsonnet';

ksm + config._config.kube_state_metrics