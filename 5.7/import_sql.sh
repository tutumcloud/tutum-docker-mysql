#!/bin/bash

if [[ $# -ne 3 ]]; then
	echo "Usage: $0 <username> <password> </path/to/sql_file.sql>"
	exit 1
fi

echo "=> Starting MySQL Server"
/usr/bin/mysqld_safe > /dev/null 2>&1 &
PID=$!

RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for confirmation of MySQL service startup"
    sleep 5
    mysql -u"$1" -p"$2" -e "status" > /dev/null 2>&1
RET=$?
done

echo "   Started with PID ${PID}"

echo "=> Importing SQL file"
mysql -u"$1" -p"$2" < "$3"

echo "=> Stopping MySQL Server"
mysqladmin -u"$1" -p"$2" shutdown

echo "=> Done!"
