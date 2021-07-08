local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local config = import 'config.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      containerPort = k.core.v1.containerPort,
      service = k.core.v1.service;

config {
  _images+:: {
    jenkins: 'jenkins/jenkins:lts-jdk11',
  },

  _config+:: {
    namespace: 'jenkins',
  },

  namespace: k.core.v1.namespace.new($._config.namespace),

  jenkins_pvc: nfspvc.new(
    $._config.namespace,
    $._config.jenkins.pvc.nfsHost,
    $._config.jenkins.pvc.nfsPath,
    'jenkinsdata',
  ),

  jenkins_container::
    container.new('jenkins', $._images.jenkins) +
    container.withPorts([
      containerPort.newNamed(name='http-metrics', containerPort=8080),
    ]) +
    container.withVolumeMountsMixin(
      k.core.v1.volumeMount.new('jenkinsdata', '/var/jenkins_home'),
    ) +
    container.securityContext.withRunAsUser(0),

  jenkins_deployment:
    deployment.new('jenkins', 1, $.jenkins_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.spec.template.spec.withVolumesMixin(
      k.core.v1.volume.fromPersistentVolumeClaim('jenkinsdata', 'jenkinsdata-pvc')
    ) +
    deployment.spec.template.metadata.withAnnotationsMixin(
      {
      'prometheus.io/path': '/prometheus',
      'prometheus.io/port': '8080',
      'prometheus.io/scrape': 'true',
      },
    ),

  jenkins_service:
    k.util.serviceFor($.jenkins_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),
}
