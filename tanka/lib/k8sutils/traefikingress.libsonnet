{
  new(name, entryPoints, routes):: {
    local this = self,

    local has_namespace = std.objectHasAll(self, '_namespace'),
    local has_labels = std.objectHasAll(self, '_labels'),

    local entrypointslist = if std.isArray(entryPoints) then entryPoints else [entryPoints],
    local routelist = if std.isArray(routes) then routes else [routes],

    ingress: {
      apiVersion: 'traefik.containo.us/v1alpha1',
      kind: 'IngressRoute',
      metadata: {
        name: name,
      } +
      (if has_namespace then { namespace: this._namespace } else {}) +
      (if has_labels then { labels: this._labels } else {}),
      spec: {
        entryPoints: entrypointslist,
        routes: routelist,
      }
    }
  },

  withNamespace(namespace):: { _namespace:: namespace },
  withLabels(labels):: { _labels:: labels },
}
