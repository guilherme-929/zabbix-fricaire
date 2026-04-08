#!/bin/bash
# Copyright Guilherme Santos 2021 ##

docker exec -i  mariadb perl /etc/mysql/mariadb.conf.d/mysql_part.pl schedule:run

echo "Done."

