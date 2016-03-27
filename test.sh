#!/bin/bash

set -e

echo "=> Building mysql 5.5 image"
docker build -t mysql-5.5 5.5/

echo "=> Testing if mysql is running on 5.5"
docker run -d -p 13306:3306 -e MYSQL_USER="user" -e MYSQL_PASS="test" mysql-5.5; sleep 10
mysqladmin -uuser -ptest -h127.0.0.1 -P13306 ping | grep -c "mysqld is alive"

echo "=> Testing replication on mysql 5.5"
docker run -d -e MYSQL_USER=user -e MYSQL_PASS=test -e REPLICATION_MASTER=true -e REPLICATION_USER=repl -e REPLICATION_PASS=repl -p 13307:3306 --name mysql55master mysql-5.5; sleep 10
docker run -d -e MYSQL_USER=user -e MYSQL_PASS=test -e REPLICATION_SLAVE=true -p 13308:3306 --link mysql55master:mysql mysql-5.5; sleep 10
docker logs mysql55master | grep "repl:repl"
mysql -uuser -ptest -h127.0.0.1 -P13307 -e "show master status\G;" | grep "mysql-bin.*"
mysql -uuser -ptest -h127.0.0.1 -P13308 -e "show slave status\G;" | grep "Slave_IO_Running.*Yes"
mysql -uuser -ptest -h127.0.0.1 -P13308 -e "show slave status\G;" | grep "Slave_SQL_Running.*Yes"

echo "=> Testing volume on mysql 5.5"
mkdir vol55
docker run --name mysql55.1 -d -p 13309:3306 -e MYSQL_USER="user" -e MYSQL_PASS="test" -v "$(pwd)/vol55":/var/lib/mysql mysql-5.5; sleep 10
mysqladmin -uuser -ptest -h127.0.0.1 -P13309 ping | grep -c "mysqld is alive"
docker stop mysql55.1
docker run  -d -p 13310:3306 -v "$(pwd)/vol55":/var/lib/mysql mysql-5.5; sleep 10
mysqladmin -uuser -ptest -h127.0.0.1 -P13310 ping | grep -c "mysqld is alive"

echo "=> Building mysql 5.6 image"
docker build -t mysql-5.6 5.6/

echo "=> Testing if mysql is running on 5.6"
docker run -d -p 23306:3306 -e MYSQL_USER="user" -e MYSQL_PASS="test" mysql-5.6; sleep 10
mysqladmin -uuser -ptest -h127.0.0.1 -P23306 ping | grep -c "mysqld is alive"

echo "=> Testing replication on mysql 5.6"
docker run -d -e MYSQL_USER=user -e MYSQL_PASS=test -e REPLICATION_MASTER=true -e REPLICATION_USER=repl -e REPLICATION_PASS=repl -p 23307:3306 --name mysql56master mysql-5.6; sleep 10
docker run -d -e MYSQL_USER=user -e MYSQL_PASS=test -e REPLICATION_SLAVE=true -p 23308:3306 --link mysql56master:mysql mysql-5.6; sleep 10
docker logs mysql56master | grep "repl:repl"
mysql -uuser -ptest -h127.0.0.1 -P23307 -e "show master status\G;" | grep "mysql-bin.*"
mysql -uuser -ptest -h127.0.0.1 -P23308 -e "show slave status\G;" | grep "Slave_IO_Running.*Yes"
mysql -uuser -ptest -h127.0.0.1 -P23308 -e "show slave status\G;" | grep "Slave_SQL_Running.*Yes"

echo "=> Testing volume on mysql 5.6"
mkdir vol56
docker run --name mysql56.1 -d -p 23309:3306 -e MYSQL_USER="user" -e MYSQL_PASS="test" -v "$(pwd)/vol56":/var/lib/mysql mysql-5.6; sleep 10
mysqladmin -uuser -ptest -h127.0.0.1 -P23309 ping | grep -c "mysqld is alive"
docker stop mysql56.1
docker run  -d -p 23310:3306 -v "$(pwd)/vol56":/var/lib/mysql mysql-5.6; sleep 10
mysqladmin -uuser -ptest -h127.0.0.1 -P23310 ping | grep -c "mysqld is alive"

echo "=>Done"
