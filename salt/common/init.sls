common_packages:
  pkg.installed:
    - pkgs:
      - curl
      - wget
      - vim
      - jq
      - gnupg
      - ca-certificates
      - python3-pip
      - chrony

chrony_service:
  service.running:
    - name: chrony
    - enable: True
    - require:
      - pkg: common_packages

salt_master_host:
  host.present:
    - ip: {{ pillar['cluster']['controller_ip'] }}
    - names:
      - salt
      - {{ pillar['cluster']['controller'] }}

salt_compute_host:
  host.present:
    - ip: {{ pillar['cluster']['compute_ip'] }}
    - names:
      - compute