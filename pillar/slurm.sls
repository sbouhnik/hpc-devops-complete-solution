cluster:
  name: research
  controller: controller
  controller_ip: 192.168.56.11
  compute_ip: 192.168.56.12
  gateway_url: http://metrics-gateway.default.svc.cluster.local:8080/update-metric
slurm:
  db_name: slurm_acct_db
  db_user: slurm
