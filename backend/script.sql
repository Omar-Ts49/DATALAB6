CREATE DATABASE IF NOT EXISTS lab3;
USE lab3;
-- I had to change the host from '%' to '127.0.0.1' since when we were testing we faced some permission issues forbiden for ('%': which meant any host) but allowed for '127.0.0.1'
CREATE USER 'mnhs_user'@'127.0.0.1' IDENTIFIED BY 'STRONG_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON lab3.* TO 'mnhs_user'@'127.0.0.1';
FLUSH PRIVILEGES;