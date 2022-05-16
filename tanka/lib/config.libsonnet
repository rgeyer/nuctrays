{
  _config+:: {
    mysql+:: {
      secondary: {
        pvc: {
          nfsHost: '192.168.42.103',
          nfsPath: '/mnt/brick/nfs/mysql-secondary',
        },
      },
    },

    certbot+:: {
      pvc: {
        nfsHost: '192.168.42.100',
        nfsPath: '/mnt/brick/nfs/certbot',
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
        nfsHost: '192.168.42.100',
        nfsPath: '/mnt/brick/nfs/traybkups',
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

    registry+:: {
      pvc: {
        nfsHost: '192.168.42.101',
        nfsPath: '/mnt/brick/nfs/registry',
      },
    },

    traefik+:: {
      private: {
        pvc: {
          nfsHost: '192.168.42.100',
          nfsPath: '/mnt/brick/nfs/traefik',
        },
      },
      public: {
        pvc: {
          nfsHost: '192.168.42.100',
          nfsPath: '/mnt/brick/nfs/ptraefik',
        },
      },
    },

    mqtt+:: {
      pvc: $._config.certbot.pvc,
    },

    cronjobs+:: {
      rclone+:: {
        'bignasty-backups-nuctray': '0 5 * * *', # 10p Pacific/5a UTC Daily
        'bignasty-code': '5 5 * * *', # 10:05p Pacific/5:05a UTC Daily
        'bignasty-download': '10 5 * * *', # 10:10p Pacific/5:10a UTC Daily
        'bignasty-homes': '15 5 * * *', # 10:15p Pacific/5:15a UTC Daily
        'bignasty-kubestore': '20 5 * * *', # 10:20p Pacific/5:20a UTC Daily        
        'bignasty-multimedia': '25 5 * * *', # 10:25p Pacific/5:25a UTC Daily
        'bignasty-public': '30 5 * * *', # 10:30p Pacific/5:30a UTC Daily
      },
    },
  }
}
