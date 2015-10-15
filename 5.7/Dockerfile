FROM ubuntu:trusty
MAINTAINER Borja <borja@libcrack.so>

ENV DEBIAN_FRONTEND=noninteractive

# Add MySQL configuration
ADD my.cnf /etc/mysql/conf.d/my.cnf
ADD mysqld_charset.cnf /etc/mysql/conf.d/mysqld_charset.cnf

# Add MySQL APT repos
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
RUN echo "deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-5.7-dmr" \
    > /etc/apt/sources.list.d/mysql.list

# Install MySQL
RUN apt-get update && \
    apt-get -yq install mysql-server-5.7 pwgen && \
    rm -rf /var/lib/apt/lists/* && \
    if [ ! -f /usr/share/mysql/my-default.cnf ] ; then cp /etc/mysql/my.cnf /usr/share/mysql/my-default.cnf; fi && \
    rm -rf /var/lib/mysql/* && \
    mysqld --initialize > /dev/null 2>&1 && \
    touch /var/lib/mysql/.EMPTY_DB

# Add MySQL scripts
ADD import_sql.sh /import_sql.sh
ADD run.sh /run.sh

ENV MYSQL_USER=admin \
    MYSQL_PASS=**Random** \
    ON_CREATE_DB=**False** \
    REPLICATION_MASTER=**False** \
    REPLICATION_SLAVE=**False** \
    REPLICATION_USER=replica \
    REPLICATION_PASS=replica

# Add VOLUMEs to allow backup of config and databases
VOLUME  ["/etc/mysql", "/var/lib/mysql"]

EXPOSE 3306
CMD ["/run.sh"]
