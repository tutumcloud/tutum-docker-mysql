#!/bin/bash
# jue oct 15 13:18:38 CEST 2015
# borja@libcrack.so

set -e

mysql_docker_test_release()
{
    local major="5"
    local minor="7"

    [[ -z "$major" ]] || major="$1"
    [[ -z "$minor" ]] || major="$2"

    local release="${major}.${minor}"

    local lport="$(($RANDOM+1024))"
    local lport_master="$(($lport+1))"
    local lport_slave="$(($lport+2))"
    local lport_vol="$(($lport+3))"
    local lport_vol2="$(($lport+4))"

    echo -e "\e[1m=> Building mysql ${release} image\e[0m"
    docker build -t mysql-${release} ${release}/

    echo -e "\e[1m=> Testing if mysql is running on ${release}"
    docker run -d -p ${lport}:3306 -e MYSQL_USER="user" -e MYSQL_PASS="test" mysql-${release}
    sleep 10
    mysqladmin -uuser -ptest -h127.0.0.1 -P${lport} ping | grep -c "mysqld is alive"

    echo -e "\e[1m=> Testing replication on mysql ${release}\e[0m"
    docker run -d -e MYSQL_USER=user -e MYSQL_PASS=test -e REPLICATION_MASTER=true \
        -e REPLICATION_USER=repl -e REPLICATION_PASS=repl -p ${lport_master}:3306 \
        --name mysql${release//.}master mysql-${release}; sleep 10
    docker run -d -e MYSQL_USER=user -e MYSQL_PASS=test -e REPLICATION_SLAVE=true \
        -p ${lport_slave}:3306 --link mysql${release//.}master:mysql mysql-${release}
    sleep 10
    docker logs mysql${release//.}master | grep "repl:repl"
    mysql -uuser -ptest -h127.0.0.1 -P${lport_master} -e "show master status\G;" | grep "mysql-bin.*"
    mysql -uuser -ptest -h127.0.0.1 -P${lport_slave} -e "show slave status\G;" | grep "Slave_IO_Running.*Yes"
    mysql -uuser -ptest -h127.0.0.1 -P${lport_slave} -e "show slave status\G;" | grep "Slave_SQL_Running.*Yes"

    echo -e "\e[1m=> Testing volume on mysql ${release}\e[0m"
    mkdir vol${release//.}
    docker run --name mysql${release//.}.1 -d -p ${lport_vol}:3306 -e MYSQL_USER="user" -e MYSQL_PASS="test" \
        -v $(pwd)/vol${release//.}:/var/lib/mysql mysql-${release}
    sleep 10
    mysqladmin -uuser -ptest -h127.0.0.1 -P${lport_vol} ping | grep -c "mysqld is alive"
    docker stop mysql${release//.}.1
    docker run  -d -p ${lport_vol2}:3306 -v $(pwd)/vol${release//.}:/var/lib/mysql mysql-${release}; sleep 10
    mysqladmin -uuser -ptest -h127.0.0.1 -P${lport_vol2} ping | grep -c "mysqld is alive"
}

mysql_docker_test_release 5 5
mysql_docker_test_release 5 6
mysql_docker_test_release 5 7

echo -e "\e[1m DONE \e[0m"
