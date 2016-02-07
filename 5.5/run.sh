#!/bin/bash

set -m
set -e

VOLUME_HOME="/var/lib/mysql"
CONF_FILE="/etc/mysql/conf.d/my.cnf"
LOG="/var/log/mysql/error.log"

# Set permission of config file
chmod 644 ${CONF_FILE}
chmod 644 /etc/mysql/conf.d/mysqld_charset.cnf

StartMySQL ()
{
    /usr/bin/mysqld_safe ${EXTRA_OPTS} > /dev/null 2>&1 &
    # Time out in 1 minute
    LOOP_LIMIT=60
    for (( i=0 ; ; i++ )); do
        if [ ${i} -eq ${LOOP_LIMIT} ]; then
            echo "Time out. Error log is shown as below:"
            tail -n 100 ${LOG}
            exit 1
        fi
        echo "=> Waiting for confirmation of MySQL service startup, trying ${i}/${LOOP_LIMIT} ..."
        sleep 1
        mysql -uroot -e "status" > /dev/null 2>&1 && break
    done
}

CreateMySQLUser()
{
    if [ "$MYSQL_PASS" = "**Random**" ]; then
        unset MYSQL_PASS
    fi

    PASS=${MYSQL_PASS:-$(pwgen -s 12 1)}
    _word=$( [ ${MYSQL_PASS} ] && echo "preset" || echo "random" )
    echo "=> Creating MySQL user ${MYSQL_USER} with ${_word} password"

    mysql -uroot -e "CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '$PASS'"
    mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '${MYSQL_USER}'@'%' WITH GRANT OPTION"
    echo "=> Done!"
    echo "========================================================================"
    echo "You can now connect to this MySQL Server using:"
    echo ""
    echo "    mysql -u$MYSQL_USER -p$PASS -h<host> -P<port>"
    echo ""
    echo "Please remember to change the above password as soon as possible!"
    echo "MySQL user 'root' has no password but only allows local connections"
    echo "========================================================================"
}

OnCreateDB()
{
    if [ "$ON_CREATE_DB" = "**False**" ]; then
        unset ON_CREATE_DB
    else
        echo "Creating MySQL database ${ON_CREATE_DB}"
        mysql -uroot -e "CREATE DATABASE IF NOT EXISTS ${ON_CREATE_DB};"
        echo "Database created!"
    fi
}

ImportSql()
{
    for FILE in ${STARTUP_SQL}; do
        echo "=> Importing SQL file ${FILE}"
        if [ "$ON_CREATE_DB" ]; then
            mysql -uroot "$ON_CREATE_DB" < "${FILE}"
        else
            mysql -uroot < "${FILE}"
        fi
    done
}

# Main
if [ ${REPLICATION_MASTER} == "**False**" ]; then
    unset REPLICATION_MASTER
fi

if [ ${REPLICATION_SLAVE} == "**False**" ]; then
    unset REPLICATION_SLAVE
fi

# Initialize empty data volume and create MySQL user
if [[ ! -d $VOLUME_HOME/mysql ]]; then
    echo "=> An empty or uninitialized MySQL volume is detected in $VOLUME_HOME"
    echo "=> Installing MySQL ..."
    if [ ! -f /usr/share/mysql/my-default.cnf ] ; then
        cp /etc/mysql/my.cnf /usr/share/mysql/my-default.cnf
    fi
    mysql_install_db || exit 1
    touch /var/lib/mysql/.EMPTY_DB
    echo "=> Done!"
else
    echo "=> Using an existing volume of MySQL"
fi

# Set MySQL REPLICATION - MASTER
if [ -n "${REPLICATION_MASTER}" ]; then
    echo "=> Configuring MySQL replication as master (1/2) ..."
    if [ ! -f /flags/replication_set.1 ]; then
        RAND="$(date +%s | rev | cut -c 1-2)$(echo ${RANDOM})"
        echo "=> Writting configuration file '${CONF_FILE}' with server-id=${RAND}"
        sed -i "s/^#server-id.*/server-id = ${RAND}/" ${CONF_FILE}
        sed -i "s/^#log-bin.*/log-bin = mysql-bin/" ${CONF_FILE}
        touch /flags/replication_set.1
    else
        echo "=> MySQL replication master already configured, skip"
    fi
fi

# Set MySQL REPLICATION - SLAVE
if [ -n "${REPLICATION_SLAVE}" ]; then
    echo "=> Configuring MySQL replication as slave (1/2) ..."
    if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ] && [ -n "${MYSQL_PORT_3306_TCP_PORT}" ]; then
        if [ ! -f /flags/replication_set.1 ]; then
            RAND="$(date +%s | rev | cut -c 1-2)$(echo ${RANDOM})"
            echo "=> Writting configuration file '${CONF_FILE}' with server-id=${RAND}"
            sed -i "s/^#server-id.*/server-id = ${RAND}/" ${CONF_FILE}
            sed -i "s/^#log-bin.*/log-bin = mysql-bin/" ${CONF_FILE}
            touch /flags/replication_set.1
        else
            echo "=> MySQL replication slave already configured, skip"
        fi
    else
        echo "=> Cannot configure slave, please link it to another MySQL container with alias as 'mysql'"
        exit 1
    fi
fi


echo "=> Starting MySQL ..."
StartMySQL
tail -F $LOG &

# Create admin user and pre create database
if [ -f /var/lib/mysql/.EMPTY_DB ]; then
    echo "=> Creating admin user ..."
    CreateMySQLUser
    OnCreateDB
    rm /var/lib/mysql/.EMPTY_DB
fi


# Import Startup SQL
if [ -n "${STARTUP_SQL}" ]; then
    if [ ! -f /flags/sql_imported ]; then
        echo "=> Initializing DB with ${STARTUP_SQL}"
        ImportSql
        touch /flags/sql_imported
    fi
fi

# Set MySQL REPLICATION - MASTER
if [ -n "${REPLICATION_MASTER}" ]; then
    echo "=> Configuring MySQL replication as master (2/2) ..."
    if [ ! -f /flags/replication_set.2 ]; then
        echo "=> Creating a log user ${REPLICATION_USER}:${REPLICATION_PASS}"
        mysql -uroot -e "CREATE USER '${REPLICATION_USER}'@'%' IDENTIFIED BY '${REPLICATION_PASS}'"
        mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* TO '${REPLICATION_USER}'@'%'"
        mysql -uroot -e "reset master"
        echo "=> Done!"
        touch /flags/replication_set.2
    else
        echo "=> MySQL replication master already configured, skip"
    fi
fi

# Set MySQL REPLICATION - SLAVE
if [ -n "${REPLICATION_SLAVE}" ]; then
    echo "=> Configuring MySQL replication as slave (2/2) ..."
    if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ] && [ -n "${MYSQL_PORT_3306_TCP_PORT}" ]; then
        if [ ! -f /flags/replication_set.2 ]; then
            echo "=> Setting master connection info on slave"
            mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='${MYSQL_PORT_3306_TCP_ADDR}',MASTER_USER='${MYSQL_ENV_REPLICATION_USER}',MASTER_PASSWORD='${MYSQL_ENV_REPLICATION_PASS}',MASTER_PORT=${MYSQL_PORT_3306_TCP_PORT}, MASTER_CONNECT_RETRY=30"
            mysql -uroot -e "start slave"
            echo "=> Done!"
            touch /flags/replication_set.2
        else
            echo "=> MySQL replication slave already configured, skip"
        fi
    else
        echo "=> Cannot configure slave, please link it to another MySQL container with alias as 'mysql'"
        exit 1
    fi
fi

fg
