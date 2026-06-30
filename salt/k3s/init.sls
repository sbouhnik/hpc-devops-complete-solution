install_k3s:
  cmd.run:
    - name: curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
    - creates: /usr/local/bin/k3s

helm_install:
  cmd.run:
    - name: |
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    - creates: /usr/local/bin/helm

load_gateway_image:
  cmd.run:
    - name: |
        set -e
        mkdir -p /var/lib/rancher/k3s/agent/images
        k3s ctr images import /vagrant/artifacts/images/metrics-gateway.tar
        touch /var/lib/rancher/k3s/agent/images/metrics-gateway.imported
    - onlyif: test -f /vagrant/artifacts/images/metrics-gateway.tar
    - unless: k3s ctr images list | grep -F 'localhost/metrics-gateway:local'
    - creates: /var/lib/rancher/k3s/agent/images/metrics-gateway.imported
    - require:
      - cmd: install_k3s

copy_gateway_chart:
  file.recurse:
    - name: /opt/metrics-gateway-chart
    - source: salt://helm/metrics-gateway
    - makedirs: True

step_2_wait_resource:
  cmd.run:
    - name: kubectl wait --for=create ingressclass/traefik --timeout=240s
    - require:
      - cmd: install_k3s
