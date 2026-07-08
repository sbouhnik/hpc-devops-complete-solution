{% set slurm_dashboard_json = salt['cp.get_file_str']('salt://grafana/files/live-slurm-job-load-dashboard.json') %}

include:
  - k3s

prometheus_values:
  file.managed:
    - name: /tmp/kube-prometheus-values.yaml
    - contents: |
        grafana:
          adminUser: {{ pillar['grafana']['admin_user'] }}
          adminPassword: {{ pillar['grafana']['admin_password'] }}
          service:
            type: NodePort
            port: 80
            targetPort: 3000
            nodePort: 32000
          dashboardProviders:
            dashboardproviders.yaml:
              apiVersion: 1
              providers:
              - name: default
                orgId: 1
                folder: default
                type: file
                disableDeletion: false
                editable: true
                options:
                  path: /var/lib/grafana/dashboards/default
          dashboards:
            default:
              node-exporter-full:
                gnetId: 1860
                revision: 37
                datasource: Prometheus
              live-slurm-job-load:
                json: |
{{ slurm_dashboard_json | indent(18, true) }}
        prometheus:
          prometheusSpec:
            additionalScrapeConfigs:
              - job_name: controller-node-exporter
                static_configs:
                  - targets: ['{{ pillar['cluster']['controller_ip'] }}:9100']
              - job_name: compute-node-exporter
                static_configs:
                  - targets: ['{{ pillar['cluster']['compute_ip'] }}:9100']
              - job_name: slurm-metrics-gateway
                metrics_path: /metrics
                static_configs:
                  - targets: ['metrics-gateway.default.svc.cluster.local:8080']

deploy_metrics_gateway:
  cmd.run:
    - name: helm upgrade --install metrics-gateway /opt/metrics-gateway-chart --namespace default
    - env:
      - KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    - require:
      - cmd: install_k3s
      - cmd: helm_install
      - cmd: load_gateway_image
      - file: copy_gateway_chart

wait_metrics_gateway_rollout:
  cmd.run:
    - name: kubectl rollout status deployment/metrics-gateway -n default --timeout=240s
    - require:
      - cmd: load_gateway_image

install_kube_prometheus_stack:
  cmd.run:
    - name: |
        set -e
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        helm repo update
        helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -f /tmp/kube-prometheus-values.yaml --namespace monitoring --create-namespace
    - env:
      - KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    - require:
      - file: prometheus_values
      - cmd: install_k3s
      - cmd: helm_install
      - cmd: deploy_metrics_gateway


