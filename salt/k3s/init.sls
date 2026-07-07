# Salt state: deploy Flannel CNI for kubeadm clusters.
#
# Pillar options:
#   kubernetes:
#     pod_network_cidr: 10.244.0.0/16
#   flannel:
#     backend_type: vxlan
#     manifest_url: https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
#
# This state assumes kubectl is configured on the node where the state runs,
# usually the first control-plane node.

{% set pod_network_cidr = salt['pillar.get']('kubernetes:pod_network_cidr', '10.244.0.0/16') %}
{% set flannel_backend = salt['pillar.get']('flannel:backend_type', 'vxlan') %}
{% set flannel_manifest_url = salt['pillar.get']('flannel:manifest_url', 'https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml') %}
{% set flannel_dir = '/opt/kubernetes/manifests/flannel' %}

/etc/rancher/k3s:
  file.directory:
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

/etc/rancher/k3s/config.yaml:
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: /etc/rancher/k3s
    - contents: |
        snapshotter: native

make-rshared-root-unit:
  file.managed:
    - name: /etc/systemd/system/make-rshared-root.service
    - mode: '0644'
    - contents: |
        [Unit]
        Description=Make root mount rshared for Kubernetes
        Before=kubelet.service

        [Service]
        Type=oneshot
        ExecStart=/usr/bin/mount --make-rshared /
        RemainAfterExit=yes

        [Install]
        WantedBy=multi-user.target

reload-systemd-for-rshared-root:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: make-rshared-root-unit

make-rshared-root-service:
  service.running:
    - name: make-rshared-root
    - enable: true
    - require:
      - cmd: reload-systemd-for-rshared-root

install_k3s:
  cmd.run:
    - name: curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --disable traefik
    - creates: /usr/local/bin/k3s
    - require:
      - file: /etc/rancher/k3s/config.yaml
      - service: make-rshared-root

flannel-manifest-dir:
  file.directory:
    - name: {{ flannel_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true

flannel-namespace:
  cmd.run:
    - name: kubectl create namespace kube-flannel --dry-run=client -o yaml | kubectl apply -f -
    - unless: kubectl get namespace kube-flannel

flannel-upstream-manifest:
  file.managed:
    - name: {{ flannel_dir }}/kube-flannel.upstream.yml
    - source: {{ flannel_manifest_url }}
    - skip_verify: true
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: flannel-manifest-dir

flannel-configmap:
  file.managed:
    - name: {{ flannel_dir }}/kube-flannel-cfg.yml
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: kube-flannel-cfg
          namespace: kube-flannel
          labels:
            app: flannel
            k8s-app: flannel
            tier: node
        data:
          cni-conf.json: |
            {
              "name": "cbr0",
              "cniVersion": "0.3.1",
              "plugins": [
                {
                  "type": "flannel",
                  "delegate": {
                    "hairpinMode": true,
                    "isDefaultGateway": true
                  }
                },
                {
                  "type": "portmap",
                  "capabilities": {
                    "portMappings": true
                  }
                }
              ]
            }
          net-conf.json: |
            {
              "Network": "{{ pod_network_cidr }}",
              "Backend": {
                "Type": "{{ flannel_backend }}"
              }
            }
    - require:
      - file: flannel-manifest-dir

flannel-apply-upstream:
  cmd.run:
    - name: kubectl apply -f {{ flannel_dir }}/kube-flannel.upstream.yml
    - onchanges:
      - file: flannel-upstream-manifest
    - require:
      - cmd: flannel-namespace
      - file: flannel-upstream-manifest

flannel-apply-config:
  cmd.run:
    - name: kubectl apply -f {{ flannel_dir }}/kube-flannel-cfg.yml
    - onchanges:
      - file: flannel-configmap
    - require:
      - cmd: flannel-namespace
      - file: flannel-configmap

flannel-rollout-after-config-change:
  cmd.run:
    - name: kubectl -n kube-flannel rollout restart daemonset/kube-flannel-ds
    - onchanges:
      - cmd: flannel-apply-config
    - require:
      - cmd: flannel-apply-config

flannel-rollout-ready:
  cmd.run:
    - name: kubectl -n kube-flannel rollout status daemonset/kube-flannel-ds --timeout=180s
    - require:
      - cmd: flannel-apply-upstream
      - cmd: flannel-apply-config

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

wait_metrics_gateway_rollout:
  cmd.run:
    - name: kubectl rollout status deployment/metrics-gateway -n default --timeout=240s
    - require:
      - cmd: load_gateway_image

copy_gateway_chart:
  file.recurse:
    - name: /opt/metrics-gateway-chart
    - source: salt://helm/metrics-gateway
    - makedirs: True

#step_2_wait_resource:
#  cmd.run:
#    - name: kubectl wait --for=create ingressclass/traefik --timeout=240s
#    - require:
#      - cmd: install_k3s
