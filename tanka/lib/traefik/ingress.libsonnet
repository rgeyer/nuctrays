{
  newIngressRoute(name='', namespace='', host='', svcName='', svcPort='', public='', secure=''):: {
    ingress: {
      apiVersion: 'traefik.containo.us/v1alpha1',
      kind: 'IngressRoute',
      metadata: {
                  name: '%(name)singress' % {name: name},
                  namespace: namespace,

                } +
                if public then { labels: { traefikzone: 'public' } } else {},
      spec: {
        entryPoints: ['web'],
        routes: [
            {
                kind: 'Rule',
                match: 'Host(`%(host)s`)' % {host: host},
                services: [
                    {
                        name: svcName,
                        port: svcPort,
                    },
                ],
            } +
            if secure then {middlewares: [{name: 'redirect-websecure', namespace: 'traefik'}]} else {},
        ],
      },
    },

    tlsingress:
      if secure then {
          apiVersion: 'traefik.containo.us/v1alpha1',
      kind: 'IngressRoute',
      metadata: {
                  name: '%(name)singresstls' % {name: name},
                  namespace: namespace,

                } +
                if public then { labels: { traefikzone: 'public' } } else {},
      spec: {
        entryPoints: ['websecure'],
        routes: [
            {
                kind: 'Rule',
                match: 'Host(`%(host)s`)' % {host: host},
                services: [
                    {
                        name: svcName,
                        port: svcPort,
                    },
                ],                
            },
        ],
        tls: { certResolver: 'mydnschallenge' },
      }
      } else {},
  },
}
