local k = import 'ksonnet-util/kausal.libsonnet';

local config = import 'config.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment;

{
  _images+:: {
    hass: 'jenkins/jenkins:lts-jdk11',
  },

  _config+:: {
    namespace: 'jenkins',
  },

  jenkins_container::
    container.new('jenkins', $._images.jenkins),

  jenkins_deployment:
    deployment.new('jenkins', 1, $.jenkins_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace),
}
