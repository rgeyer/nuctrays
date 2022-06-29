{
  // TODO: Not sure if I want to actually define these, or if I should just advise the user(s) to use a jsonnet-libs/k8s-libsonnet generic.
  metadata: {
    withName(name):: {
      metadata+: { name: name },
    },
    withNamespace(namespace):: {
      metadata+: { namespace: namespace },
    },
  },

  spec: {
    withConfig(config):: {
      spec+: {
        config: config,
      },
    },
    withConfigMap(configMap):: {
      spec+: {
        configMaps+: [configMap],
      },
    },

    withName(name):: {
      spec+: {
        name: name,
      },
    },
    type: {
      withAllNodes(allNodes):: {
        spec+: {
          type+: { allNodes: allNodes },
        },
      },
      withUnique(unique):: {
        spec+: {
          type+: { unique: unique },
        },
      },
    },
  },

  new(name, allNodes, unique)::
    {
      apiVersion: 'monitoring.grafana.com/v1alpha1',
      kind: 'Integration',
      metadata: {},
      spec: {},
    } +
    self.metadata.withName(name) +
    self.spec.withName(name) +
    self.spec.type.withAllNodes(allNodes) +
    self.spec.type.withUnique(unique),

  newConfigMap(key, name='', optional=true):: {
    key: key,
    name: name,
    optional: optional,
  },
}
