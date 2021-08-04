{
  redirect: {
    apiVersion: 'traefik.containo.us/v1alpha1',
    kind: 'Middleware',
    metadata: {
      labels: {
        traefikzone: 'public',
      },
      name: 'redirect-websecure',
      namespace: 'traefik',
    },
    spec: {
      redirectScheme: {
        permanent: true,
        scheme: 'https',
      },
    },
  },

  stripprefix: {
    apiVersion: 'traefik.containo.us/v1alpha1',
    kind: 'Middleware',
    metadata: {
      labels: {
        traefikzone: 'public',
      },
      name: 'stripprefixes',
      namespace: 'traefik',
    },
    spec: {
      stripPrefix: {
        prefixes: ['/atvtest'],
      },
    },
  },
}
