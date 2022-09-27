CREATE USER 'superuser'@'%' IDENTIFIED WITH mysql_native_password BY 'superpassword';
CREATE USER 'replicator'@'%' IDENTIFIED BY 'replpass';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT  ON *.* TO 'superuser';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'replicator';

create database demo;

GRANT  SELECT, INSERT, UPDATE, DELETE ON demo.* TO connect_user;
GRANT ALL PRIVILEGES ON demo.* TO 'superuser'@'%';