local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

{
  sharedsvcns: k.core.v1.namespace.new('sharedsvc'),

  calicostaticpool: {
    apiVersion: 'crd.projectcalico.org/v1',
    kind: 'IPPool',
    metadata: {
      name: 'static',
    },
    spec: {
      blockSize: 26,
      cidr: '10.43.0.0/24',
      ipipMode: 'Never',
      nodeSelector: '!all()',
      vxlanMode: 'Never',
    },
  },
}
