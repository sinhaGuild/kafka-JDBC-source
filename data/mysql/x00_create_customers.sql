use demo;

create table customers (
	id INT,
	first_name VARCHAR(50),
	last_name VARCHAR(50),
	email VARCHAR(50),
	gender VARCHAR(50),
	club_status VARCHAR(50),
	comments VARCHAR(300),
	create_ts timestamp DEFAULT CURRENT_TIMESTAMP ,
	UPDATE_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
