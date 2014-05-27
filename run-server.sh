#!/bin/sh

# rm -rf data-mysql
mkdir -p data-mysql

# as daemon
docker run --name mysql -d -p 3306:3306 -v  $(pwd)/data-mysql:/var/lib/mysql -e MYSQL_PASS="samba" tutum/mysql 

# interactive
#docker run -i -t -p 3306:3306 -v  $(pwd)/data-mysql:/var/lib/mysql -e MYSQL_PASS="samba" tutum/mysql bash