{% set grafana_service = salt['pillar.get']('grafana:service', 'grafana-server') %}
{% set dashboard_dir = salt['pillar.get']('grafana:dashboard_dir', '/var/lib/grafana/dashboards/slurm') %}
{% set provisioning_dir = salt['pillar.get']('grafana:provisioning_dir', '/etc/grafana/provisioning/dashboards') %}

grafana-slurm-dashboard-dir:
  file.directory:
    - name: {{ dashboard_dir }}
    - user: grafana
    - group: grafana
    - mode: '0755'
    - makedirs: True

grafana-slurm-dashboard-json:
  file.managed:
    - name: {{ dashboard_dir }}/live-slurm-job-load-dashboard.json
    - source: salt://grafana/files/live-slurm-job-load-dashboard.json
    - user: grafana
    - group: grafana
    - mode: '0644'
    - require:
      - file: grafana-slurm-dashboard-dir
    - watch_in:
      - service: grafana-service

grafana-slurm-dashboard-provider:
  file.managed:
    - name: {{ provisioning_dir }}/slurm-dashboards.yaml
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - contents: |
        apiVersion: 1

        providers:
          - name: Slurm
            orgId: 1
            folder: Slurm
            type: file
            disableDeletion: false
            editable: true
            updateIntervalSeconds: 10
            options:
              path: {{ dashboard_dir }}
              foldersFromFilesStructure: false
    - watch_in:
      - service: grafana-service

grafana-service:
  service.running:
    - name: {{ grafana_service }}
    - enable: True
