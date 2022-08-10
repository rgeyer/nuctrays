local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      envFrom = k.core.v1.envFromSource,
      policyRule = k.rbac.v1.policyRule,
      secret = k.core.v1.secret,
      service = k.core.v1.service,
      serviceAccount = k.core.v1.serviceAccount,
      statefulSet = k.apps.v1.statefulSet,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount;

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

{
  // TODO: This is not particularly modular, and makes a lot of assumptions about my environment(s), but enables DRY, so it shall exist in this form for now.
  new(name, namespace, image, hostname, staticIp, nfsHost, nfsPath, certbotSecretName, labelSelector=''):: {
    local this = self,

    traefikrac:: [
      policyRule.withApiGroups(['']) +
      policyRule.withResources(['services', 'endpoints', 'secrets']) +
      policyRule.withVerbs(['get', 'list', 'watch']),

      policyRule.withApiGroups(['extensions', 'networking.k8s.io']) +
      policyRule.withResources(['ingresses', 'ingressclasses']) +
      policyRule.withVerbs(['get', 'list', 'watch']),

      policyRule.withApiGroups(['extensions']) +
      policyRule.withResources(['ingresses/status']) +
      policyRule.withVerbs(['update']),

      policyRule.withApiGroups(['traefik.containo.us']) +
      policyRule.withResources([
        'middlewares',
        'middlewaretcps',
        'ingressroutes',
        'traefikservices',
        'ingressroutetcps',
        'ingressrouteudps',
        'tlsoptions',
        'tlsstores',
        'serverstransports',
      ]) +
      policyRule.withVerbs(['get', 'list', 'watch']),
    ],

    ktraefikrbac: k { _config+:: { namespace: namespace } }.util.rbac(name, this.traefikrac) {
      service_account+: serviceAccount.mixin.metadata.withNamespace(namespace),
    },

    ktraefik_pvc: nfspvc.new(
      namespace,
      nfsHost,
      nfsPath,
      name,
    ),

    ktraefik_container::
      container.new(name, image) +
      container.withEnvFrom(envFrom.secretRef.withName(certbotSecretName)) +
      container.withPorts([
        containerPort.new('web', 80),
        containerPort.new('websecure', 443),
        containerPort.new('http-metrics', 8080),
      ]) +
      container.withArgsMixin([
        '--api.dashboard=true',
        '--entrypoints.web.Address=:80',
        '--entrypoints.websecure.Address=:443',
        '--providers.kubernetescrd',
        '--providers.kubernetescrd.allowCrossNamespace=true',
        '--certificatesresolvers.mydnschallenge.acme.dnschallenge=true',
        '--certificatesresolvers.mydnschallenge.acme.dnschallenge.provider=route53',
        '--certificatesresolvers.mydnschallenge.acme.email=qwikrex@gmail.com',
        '--certificatesresolvers.mydnschallenge.acme.storage=/etc/traefik/acme/acme.json',
        '--metrics.prometheus=true',
        '--metrics.prometheus.addEntryPointsLabels=true',
        '--metrics.prometheus.addServicesLabels=true',
        // These are implicit, but adding them for the sake of clarity
        '--entrypoints.traefik.Address=:8080',
        '--metrics.prometheus.entryPoint=traefik',
      ]
      +
      if labelSelector != '' then [
        '--providers.kubernetescrd.labelselector=%s' % labelSelector,
      ] else []
      ) +
      container.withVolumeMountsMixin([
        volumeMount.new('acme', '/etc/traefik/acme'),
      ]),

    ktraefik_statefulset:
      statefulSet.new('traefik', 1, this.ktraefik_container) +
      statefulSet.spec.withServiceName('traefik') +
      statefulSet.mixin.metadata.withNamespace(namespace) +
      statefulSet.spec.template.metadata.withAnnotations({
        'cni.projectcalico.org/ipAddrs': '["%(ip)s"]' % { ip: staticIp },
      }) +
      statefulSet.mixin.spec.template.spec.withVolumesMixin([
        volume.fromPersistentVolumeClaim('acme', '%s-pvc' % name),
      ]) +
      statefulSet.spec.template.spec.withServiceAccountName(name),

    ktraefik_svc:
      k.util.serviceFor(this.ktraefik_statefulset) +
      service.mixin.metadata.withNamespace(namespace),

    ktraefikingress: traefikingress.newTraefikServiceIngressRoute(name, namespace, hostname, 'api@internal', labelSelector != ''),
  },
}
