{
  newIngressRoute(name='', namespace='', host='', svcName='', svcPort='', public=false, secure=true)::
    $._newIngressRoute(name, namespace, host, svcName, svcPort, public, secure),

  newTraefikServiceIngressRoute(name='', namespace='', host='', traefikSvcName='', public=false, secure=true)::
    $._newIngressRoute(name, namespace, host, '', '', public, secure, traefikSvcName),

  _newIngressRoute(name='', namespace='', host='', svcName='', svcPort='', public=false, secure=true, traefikSvcName=''):: {
    ingress: {
      apiVersion: 'traefik.containo.us/v1alpha1',
      kind: 'IngressRoute',
      metadata: {
                  name: '%(name)singress' % { name: name },
                  namespace: namespace,

                } +
                if public then { labels: { traefikzone: 'public' } } else {},
      spec: {
        entryPoints: ['web'],
        routes: [
          {
            kind: 'Rule',
            match: 'Host(`%(host)s`)' % { host: host },
            services: [] +
                      if svcPort != '' then
                        [{
                          name: svcName,
                          port: svcPort,
                        }] else []
                                +
                                if traefikSvcName != '' then
                                  [{
                                    name: traefikSvcName,
                                    kind: 'TraefikService',
                                  }] else [],
          } +
          if secure then { middlewares: [{ name: 'redirect-websecure', namespace: 'traefik' }] } else {},
        ],
      },
    },

    tlsingress:
      if secure then {
        apiVersion: 'traefik.containo.us/v1alpha1',
        kind: 'IngressRoute',
        metadata: {
                    name: '%(name)singresstls' % { name: name },
                    namespace: namespace,

                  } +
                  if public then { labels: { traefikzone: 'public' } } else {},
        spec: {
          entryPoints: ['websecure'],
          routes: [
            {
              kind: 'Rule',
              match: 'Host(`%(host)s`)' % { host: host },
              services: [] +
                        if svcPort != '' then
                          [{
                            name: svcName,
                            port: svcPort,
                          }] else []
                                  +
                                  if traefikSvcName != '' then
                                    [{
                                      name: traefikSvcName,
                                      kind: 'TraefikService',
                                    }] else [],
            },
          ],
          tls: { certResolver: 'mydnschallenge' },
        },
      } else {},
  },
}
