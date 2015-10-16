#!/bin/bash
# jue oct 15 13:18:38 CEST 2015
# borja@libcrack.so

set -e

mysql_docker_test_release()
{
    local major="5"
    local minor="7"

    [[ -z "$major" ]] || major="$1"
    [[ -z "$minor" ]] || minor="$2"

    local release="${major}"."${minor}"

    local lport="$(($RANDOM+1024))"
    local lport_master="$(($lport+1))"
    local lport_slave="$(($lport+2))"
    local lport_vol="$(($lport+3))"
    local lport_vol2="$(($lport+4))"

    local user="user"
    local passwd="test"
    local host="127.0.0.1"

    local repl_user="repl"
    local repl_passwd="repl"
    local rep_host="127.0.0.1"

    echo -e "\e[1m=> Building mysql ${release} image\e[0m"

    docker build -t "mysql-${release}" "${release}/"

    echo -e "\e[1m=> Testing if mysql is running on ${release}"

    docker run -d -p "${lport}":3306 -e MYSQL_USER="${user}" -e MYSQL_PASS="${passwd}" \
        mysql-"${release}"
    sleep 10

    mysqladmin -u"${user}" -p"${passwd}" -h"${host}" -P"${lport}" ping | grep -c "mysqld is alive"

    echo -e "\e[1m=> Testing replication on mysql ${release}\e[0m"

    docker run -d -e MYSQL_USER="${user}" -e MYSQL_PASS="${passwd}" -e REPLICATION_MASTER=true \
        -e REPLICATION_USER="${repl_user}" -e REPLICATION_PASS="${repl_passwd}" -p "${lport_master}":3306 \
        --name mysql"${release//.}"master mysql-"${release}"
    sleep 10

    docker run -d -e MYSQL_USER="${user}" -e MYSQL_PASS="${passwd}" -e REPLICATION_SLAVE=true \
        -p "${lport_slave}":3306 --link mysql"${release//.}"master:mysql mysql-"${release}"
    sleep 10

    docker logs mysql"${release//.}"master | grep "repl:repl"
    mysql -u"${user}" -p"${passwd}" -h"${host}" -P"${lport_master}" -e "show master status\G;" \
        | grep "mysql-bin.*"
    mysql -u"${user}" -p"${passwd}" -h"${host}" -P"${lport_slave}"  -e "show slave status\G;"  \
        | grep "Slave_IO_Running.*Yes"
    mysql -u"${user}" -p"${passwd}" -h"${host}" -P"${lport_slave}"  -e "show slave status\G;"  \
        | grep "Slave_SQL_Running.*Yes"

    echo -e "\e[1m=> Testing volume on mysql ${release}\e[0m"

    mkdir vol"${release//.}"
    docker run --name mysql"${release//.}".1 -d -p "${lport_vol}:3306" -e MYSQL_USER="${user}" \
        -e MYSQL_PASS="${passwd}" -v "$(pwd)/vol${release//.}":/var/lib/mysql mysql-"${release}"
    sleep 10

    mysqladmin -u"${user}" -p"${passwd}" -h"${host}" -P"${lport_vol}" ping | grep -c "mysqld is alive"
    docker stop mysql"${release//.}".1
    docker run  -d -p "${lport_vol2}":3306 -v "$(pwd)/vol${release//.}":/var/lib/mysql mysql-"${release}"
    sleep 10

    mysqladmin -u"${user}" -p"${passwd}" -h"${host}" -P"${lport_vol2}" ping | grep -c "mysqld is alive"
}

echo -e "\e[1m Starting tests at $(date "+%d/%m/%Y %H:%M:%S") \e[0m"

mysql_docker_test_release 5 5
mysql_docker_test_release 5 6
mysql_docker_test_release 5 7

echo -e "\e[1m Finished tests at $(date "+%d/%m/%Y %H:%M:%S") \e[0m"

# vim:set ts=2 sw=2 et:
