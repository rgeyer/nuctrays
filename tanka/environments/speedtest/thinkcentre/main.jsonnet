local speedtest = import 'speedtest/main.libsonnet';

{
  _config:: {
    namespace: 'sharedsvc',
  },

  speedtest:
    speedtest.newDeployment(namespace=$._config.namespace) +
    speedtest.withGrafanaAgentPodMonitor(),
}
