#!/bin/bash

VOLUME_HOME="/var/lib/mysql"
CONF_FILE="/etc/mysql/conf.d/my.cnf"
LOG="/var/log/mysql/error.log"
REPLICATION_SLAVE_OPTS=${REPLICATION_SLAVE_OPTS:-''};

# Set permission of config file
chmod 644 ${CONF_FILE}
chmod 644 /etc/mysql/conf.d/mysqld_charset.cnf

StartMySQL ()
{
    /usr/bin/mysqld_safe > /dev/null 2>&1 &

    # Time out in 1 minute
    LOOP_LIMIT=13
    for (( i=0 ; ; i++ )); do
        if [ ${i} -eq ${LOOP_LIMIT} ]; then
            echo "Time out. Error log is shown as below:"
            tail -n 100 ${LOG}
            exit 1
        fi
        echo "=> Waiting for confirmation of MySQL service startup, trying ${i}/${LOOP_LIMIT} ..."
        sleep 5
        mysql -uroot -e "status" > /dev/null 2>&1 && break
    done
}

CreateMySQLUser()
{
	StartMySQL
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

	mysqladmin -uroot shutdown
}

ImportSql()
{
	StartMySQL

	for FILE in ${STARTUP_SQL}; do
	   echo "=> Importing SQL file ${FILE}"
	   mysql -uroot < "${FILE}"
	done

	mysqladmin -uroot shutdown
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
    mysql_install_db > /dev/null 2>&1
    echo "=> Done!"  
    echo "=> Creating admin user ..."
    CreateMySQLUser
else
    echo "=> Using an existing volume of MySQL"
fi

# Import Startup SQL
if [ -n "${STARTUP_SQL}" ]; then
    if [ ! -f /sql_imported ]; then
        echo "=> Initializing DB with ${STARTUP_SQL}"
        ImportSql
        touch /sql_imported
    fi
fi


# Set MySQL REPLICATION - MASTER
if [ -n "${REPLICATION_MASTER}" ]; then 
    echo "=> Configuring MySQL replication as master ..."
    if [ ! -f /replication_configured ]; then
        RAND="$(date +%s | rev | cut -c 1-2)$(echo ${RANDOM})"
        echo "=> Writting configuration file '${CONF_FILE}' with server-id=${RAND}"
        sed -i "s/^#server-id.*/server-id = ${RAND}/" ${CONF_FILE}
        sed -i "s/^#log-bin.*/log-bin = mysql-bin/" ${CONF_FILE}
        echo "=> Starting MySQL ..."
        StartMySQL
        echo "=> Creating a log user ${REPLICATION_USER}:${REPLICATION_PASS}"
        mysql -uroot -e "CREATE USER '${REPLICATION_USER}'@'%' IDENTIFIED BY '${REPLICATION_PASS}'"
        mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* TO '${REPLICATION_USER}'@'%'"
        echo "=> Done!"
        mysqladmin -uroot shutdown
        touch /replication_configured
    else
        echo "=> MySQL replication master already configured, skip"
    fi
fi

# Set MySQL REPLICATION - SLAVE
if [ -n "${REPLICATION_SLAVE}" ]; then 
    echo "=> Configuring MySQL replication as slave ..."
    if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ] && [ -n "${MYSQL_PORT_3306_TCP_PORT}" ]; then
        if [ ! -f /replication_configured ]; then
            RAND="$(date +%s | rev | cut -c 1-2)$(echo ${RANDOM})"
            echo "=> Writting configuration file '${CONF_FILE}' with server-id=${RAND}"
            sed -i "s/^#server-id.*/server-id = ${RAND}/" ${CONF_FILE}
            sed -i "s/^#log-bin.*/log-bin = mysql-bin/" ${CONF_FILE}
            echo "=> Starting MySQL ..."
            StartMySQL
            echo "=> Setting master connection info on slave"
            if [ -n "${REPLICATION_SLAVE_CURRENT}" ] ; then
                mysql -h"${MYSQL_PORT_3306_TCP_ADDR}" -u"${MYSQL_ENV_REPLICATION_USER}" -p"${MYSQL_ENV_REPLICATION_PASS}" -e 'SHOW MASTER STATUS\G' > /tmp/mysql.master.info && {
                    cat /tmp/mysql.master.info
                    FILE=$(awk -F': ' '/File/ {print $2}' /tmp/mysql.master.info);
                    POSITION=$(awk -F': ' '/Position/ {print $2}' /tmp/mysql.master.info);
                    REPLICATION_SLAVE_OPTS="${REPLICATION_SLAVE_OPTS}, MASTER_LOG_FILE='${FILE}', MASTER_LOG_POS=${POSITION}"
                    echo "Replication binlog position set to '${FILE}' '${POSITION}'"
                } || echo "FAILED to connect to master database @${MYSQL_PORT_3306_TCP_ADDR}";
            fi
            mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='${MYSQL_PORT_3306_TCP_ADDR}',MASTER_USER='${MYSQL_ENV_REPLICATION_USER}',MASTER_PASSWORD='${MYSQL_ENV_REPLICATION_PASS}',MASTER_PORT=${MYSQL_PORT_3306_TCP_PORT} ${REPLICATION_SLAVE_OPTS}, MASTER_CONNECT_RETRY=30"
            echo "=> Done!"
            mysqladmin -uroot shutdown
            touch /replication_configured
        else
            echo "=> MySQL replicaiton slave already configured, skip"
        fi
    else 
        echo "=> Cannot configure slave, please link it to another MySQL container with alias as 'mysql'"
        exit 1
    fi
fi

tail -F $LOG &
exec mysqld_safe
