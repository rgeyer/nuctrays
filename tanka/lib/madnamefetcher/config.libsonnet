{
  _config+:: {
    namespace: error 'must specify namespace',
    namefetcher+: {
      dbhost: error 'must define namefetcher mysql host',
      dbname: error 'must define namefetcher mysql db name',
      api_token: error 'must define namefetcher api token',
      uri: error 'must define namefetcher api uri',
    },
  },
}
