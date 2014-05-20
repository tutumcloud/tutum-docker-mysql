tutum-docker-mysql
==================

Base docker image to run a MySQL database server


MySQL version
-------------

`master` branch maintains MySQL from Ubuntu trusty official source. If you want to get different version of MySQL, please checkout `5.5` branch and `5.6` branch.

Usage
-----

To create the image `tutum/mysql`, execute the following command on the tutum-mysql folder:

	docker build -t tutum/mysql .

To run the image and bind to port 3306:

	docker run -d -p 3306:3306 tutum/mysql

The first time that you run your container, a new user `admin` with all privileges 
will be created in MySQL with a random password. To get the password, check the logs
of the container by running:

	docker logs <CONTAINER_ID>

You will see an output like the following:

	========================================================================
	You can now connect to this MySQL Server using:

	    mysql -uadmin -p47nnf4FweaKu -h<host> -P<port>

	Please remember to change the above password as soon as possible!
	MySQL user 'root' has no password but only allows local connections
	========================================================================

In this case, `47nnf4FweaKu` is the password allocated to the `admin` user.

Remember that the `root` user has no password but it's only accesible from within the container.

You can now test your deployment:

	mysql -uadmin -p

Done!


Setting a specific password for the admin account
-------------------------------------------------

If you want to use a preset password instead of a random generated one, you can
set the environment variable `MYSQL_PASS` to your specific password when running the container:

	docker run -d -p 3306:3306 -e MYSQL_PASS="mypass" tutum/mysql

You can now test your deployment:

	mysql -uadmin -p"mypass"


Mounting the database file volume
---------------------------------

In order to persist the database data, you can mount a local folder from the host 
on the container to store the database files. To do so:

	docker run -d -v /path/in/host:/var/lib/mysql tutum/mysql /bin/bash -c "/usr/bin/mysql_install_db"

This will mount the local folder `/path/in/host` inside the docker in `/var/lib/mysql` (where MySQL will store the database files by default). `mysql_install_db` creates the initial database structure.

Remember that this will mean that your host must have `/path/in/host` available when you run your docker image!

After this you can start your mysql image but this time using `/path/in/host` as the database folder:

	docker run -d -p 3306:3306 -v /path/in/host:/var/lib/mysql tutum/mysql


Mounting the database file volume from other containers
------------------------------------------------------

Another way to persist the database data is to store database files in another container.
To do so, first create a container that holds database files:

    docker run -d -v /var/lib/mysql --name db_vol -p 22:22 tutum/ubuntu-trusty 

This will create a new ssh-enabled container and use its folder `/var/lib/mysql` to store MySQL database files. 
You can specify any name of the container by using `--name` option, which will be used in next step.

After this you can start your MySQL image using volumes in the container created above (put the name of container in `--volumes-from`)

    docker run -d --volumes-from db_vol -p 3306:3306 tutum/mysql 


Migrating an existing MySQL Server
----------------------------------

In order to migrate your current MySQL server, perform the following commands from your current server:

To dump your databases structure:

	mysqldump -u<user> -p --opt -d -B <database name(s)> > /tmp/dbserver_schema.sql

To dump your database data:

	mysqldump -u<user> -p --quick --single-transaction -t -n -B <database name(s)> > /tmp/dbserver_data.sql

To import a SQL backup which is stored for example in the folder `/tmp` in the host, run the following:

	sudo docker run -d -v /tmp:/tmp tutum/mysql /bin/bash -c "/import_sql.sh <rootpassword> /tmp/<dump.sql>")

Where `<rootpassword>` is the root password set earlier and `<dump.sql>` is the name of the SQL file to be imported.


Environment variables
---------------------

`MYSQL_PASS`: Set a specific password for the admin account.
