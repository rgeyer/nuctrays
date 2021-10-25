{
  _config+:: {
    certbot+:: {
      pvc: {
        nfsHost: '192.168.42.10',
        nfsPath: '/kubestore/certbot',
      }
    },

    cortex+:: {
      pvc: {
        nfsHost: '192.168.42.100',
        nfsPath: '/mnt/brick/nfs/cortex',
      }
    },

    backups+:: {
      pvc: {
        nfsHost: '192.168.42.10',
        nfsPath: '/Backups/nuctray/eighteen',
      }
    },

    jenkins+:: {
      pvc: {
        nfsHost: '192.168.42.100',
        nfsPath: '/mnt/brick/nfs/jenkins',
      }
    },

    kube_state_metrics+:: {
      name:: 'kube-state-metrics',
      namespace:: 'kube-system',
      version:: 'v2.2.1',
      image:: 'k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.2.1',
      commonLabels+:: {
          // So that the grafana-agent default kubernetes_sd_config can find it
          'name': 'kube-state-metrics',
      },      
    },

    minio+:: {
      pvc: {
        nfsHost: '192.168.42.101',
        nfsPath: '/mnt/brick/nfs/minio',
      },
    },

    loki+:: {
      pvc: {
        nfsHost: '192.168.42.101',
        nfsPath: '/mnt/brick/nfs/loki',
      }
    },
  }
}
