node_exporter_container:
  cmd.run:
    - name: |
        podman rm -f node-exporter || true
        podman run -d --name node-exporter --restart=always --net=host --pid=host           -v /:/host:ro,rslave quay.io/prometheus/node-exporter:latest           --path.rootfs=/host
    - unless: podman container exists node-exporter
    - require:
      - pkg: podman
