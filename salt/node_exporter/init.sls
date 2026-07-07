/etc/containers:
  file.directory:
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

/etc/containers/containers.conf:
  file.managed:
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: /etc/containers
    - contents: |
        [engine]
        cgroup_manager = "cgroupfs"
        events_logger = "file"
        runtime = "crun"

node_exporter_container:
  cmd.run:
    - name: |
        podman rm -f node-exporter || true
        podman run -d --name node-exporter --restart=always --net=host --pid=host           -v /:/host:ro,rslave quay.io/prometheus/node-exporter:latest           --path.rootfs=/host
    - unless: podman container exists node-exporter
    - require:
      - pkg: podman
      - file: /etc/containers/containers.conf

