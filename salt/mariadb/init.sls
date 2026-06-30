mariadb_pkgs:
  pkg.installed:
    - pkgs: [mariadb-server, python3-pymysql]

mariadb_service:
  service.running:
    - name: mariadb
    - enable: True
    - require:
      - pkg: mariadb_pkgs

slurm_database:
  cmd.run:
    - name: mysql -uroot -e "CREATE DATABASE IF NOT EXISTS \`{{ pillar['slurm']['db_name'] }}\`;"
    - unless: mysql -uroot -e "SHOW DATABASES LIKE '{{ pillar['slurm']['db_name'] }}';" | grep {{ pillar['slurm']['db_name'] }}
    - require:
      - service: mariadb_service

slurm_db_user:
  cmd.run:
    - name: |
        mysql -uroot -e "CREATE USER IF NOT EXISTS '{{ pillar['slurm']['db_user'] }}'@'localhost' IDENTIFIED BY '{{ pillar['slurm']['db_password'] }}';"
        mysql -uroot -e "GRANT ALL PRIVILEGES ON \`{{ pillar['slurm']['db_name'] }}\`.* TO '{{ pillar['slurm']['db_user'] }}'@'localhost';"
        mysql -uroot -e "FLUSH PRIVILEGES;"
    - unless: mysql -uroot -e "SELECT User FROM mysql.user WHERE User='{{ pillar['slurm']['db_user'] }}' AND Host='localhost';" | grep {{ pillar['slurm']['db_user'] }}
    - require:
      - cmd: slurm_database

#slurm_database:
#  mysql_database.present:
#    - name: {{ pillar['slurm']['db_name'] }}
#    - connection_unix_socket: /run/mysqld/mysqld.sock
#    - require:
#      - service: mariadb_service

#slurm_db_user:
#  mysql_user.present:
#    - name: {{ pillar['slurm']['db_user'] }}
#    - password: {{ pillar['slurm']['db_password'] }}
#    - host: '%'
#    - connection_unix_socket: /run/mysqld/mysqld.sock
#    - require:
#      - service: mariadb_service

#slurm_db_grants:
#  mysql_grants.present:
#    - grant: all privileges
#    - database: {{ pillar['slurm']['db_name'] }}.*
#    - user: {{ pillar['slurm']['db_user'] }}
#    - host: '%'
#    - connection_unix_socket: /run/mysqld/mysqld.sock
