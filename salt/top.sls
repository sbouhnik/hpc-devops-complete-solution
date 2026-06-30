base:
  '*':
    - common
    - munge
    - slurm
  'controller':
    - podman
    - mariadb
    - node_exporter
  'compute':
    - k3s
    - grafana
    - cron
