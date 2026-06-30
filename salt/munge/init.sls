munge_pkg:
  pkg.installed:
    - pkgs: [munge, libmunge2]

/etc/munge/munge.key:
  file.managed:
    - user: munge
    - group: munge
    - mode: '0400'
    - contents_pillar: munge:key
    - require:
      - pkg: munge_pkg

munge_service:
  service.running:
    - name: munge
    - enable: True
    - watch:
      - file: /etc/munge/munge.key
