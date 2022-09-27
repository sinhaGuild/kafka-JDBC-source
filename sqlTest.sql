SELECT table_schema, table_name FROM INFORMATION_SCHEMA.tables WHERE TABLE_SCHEMA != 'information_schema';

SELECT * FROM demo.accounts LIMIT 5;

insert into demo.accounts (id, first_name, last_name, username, company, created_date) values (21, 'Hamelin', 'Billy', 'Hamelin Billy', 'Erdman-Halvorson', '2018-09-16');