# 1. Start the cluster
```
docker-compose up -d
docker-compose up -d --build --force-recreate

```


# 2. Double check all plugins are installed
```
curl -s localhost:8083/connector-plugins|jq '.[].class'

```

## 3.1 Create connectors with installed drivers

```

// CREATE SOURCE connector

curl -i -X PUT -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:8083/connectors/source-csv-spooldir-00/config \
    -d '{
        "connector.class": "com.github.jcustenborder.kafka.connect.spooldir.SpoolDirCsvSourceConnector",
        "topic": "orders_spooldir_00",
        "input.path": "/data/unprocessed",
        "finished.path": "/data/processed",
        "error.path": "/data/error",
        "input.file.pattern": ".*\\.csv",
        "schema.generation.enabled":"true",
        "csv.first.row.as.header":"true"
        }'
    
```

### 3.1.2 Check by consuming the data using kafkacat. 

        ```
        docker exec kafkacat kafkacat -b broker:29092 -L -J|jq '.topics[].topic' | sort

        //Show me the last message -o-1, spit it out as json and only return the payload
        docker exec kafkacat kafkacat -b broker:29092 -t orders_spooldir_00 -C -o-1 -J -s key=s -s value=avro -r http://schema-registry:8081 |jq '.payload'

        //Show me the last message -o-1, spit it out as json and return everything.
        docker exec kafkacat kafkacat -b broker:29092 -t orders_spooldir_00 -C -o-1 -J -s key=s -s value=avro -r http://schema-registry:8081 |jq '.'

        // run an example of real time processing
        cp /data/processed/orders.csv /data/unprocessed/orders-2.csv
        //Check the 2nd terminal running kafkacat update in real time.

        ```

## 3.2 Delete the connector and recreate with _auto transform id to primary key_

    ```
    DELETE http://localhost:8083/connectors/{name}

    //Show me the last message -o-1, spit it out as json and return everything.
    docker exec kafkacat kafkacat -b broker:29092 -t orders_spooldir_01 -C -o-1 -J -s key=s -s value=avro -r http://schema-registry:8081 |jq '.'

    // New SOURCE connector config

    curl -i -X PUT -H "Accept:application/json" \
        -H  "Content-Type:application/json" http://localhost:8083/connectors/source-csv-spooldir-01/config \
        -d '{
            "connector.class": "com.github.jcustenborder.kafka.connect.spooldir.SpoolDirCsvSourceConnector",
            "topic": "orders_spooldir_01",
            "input.path": "/data/unprocessed",
            "finished.path": "/data/processed",
            "error.path": "/data/error",
            "input.file.pattern": ".*\\.csv",
            "schema.generation.enabled":"true",
            "schema.generation.key.fields":"order_id",
            "csv.first.row.as.header":"true"
            }'

    // run an example of real time processing
    cp /data/processed/orders.csv /data/unprocessed/orders-2.csv
    //Check the 2nd terminal running kafkacat update in real time.

    ```


## 3.3 Transform the _input data types_ when ingesting from source

    ```
    //delete old connector

    //move files

    // New SOURCE connector config
    curl -i -X PUT -H "Accept:application/json" \
        -H  "Content-Type:application/json" http://localhost:8083/connectors/source-csv-spooldir-02/config \
        -d '{
            "connector.class": "com.github.jcustenborder.kafka.connect.spooldir.SpoolDirCsvSourceConnector",
            "topic": "orders_spooldir_02",
            "input.path": "/data/unprocessed",
            "finished.path": "/data/processed",
            "error.path": "/data/error",
            "input.file.pattern": ".*\\.csv",
            "schema.generation.enabled":"true",
            "schema.generation.key.fields":"order_id",
            "csv.first.row.as.header":"true",
            "transforms":"castTypes",
            "transforms.castTypes.type":"org.apache.kafka.connect.transforms.Cast$Value",
            "transforms.castTypes.spec":"order_id:int32,customer_id:int32,order_total_usd:float32"
            }'

    ```

# 4. Check ingested schema from data registry

```
curl --silent --location --request GET 'http://localhost:8081/subjects/orders_spooldir_02-value/versions/latest' |jq '.schema|fromjson'

```
# 5. Load data into a postgres db

```

//Create a SINK connector

//PK.FIELD AND PK.MODE defines what the primary key in sink database will be.

curl -X PUT http://localhost:8083/connectors/sink-postgres-orders-00/config \
    -H "Content-Type: application/json" \
    -d '{
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "connection.url": "jdbc:postgresql://postgres:5432/",
        "connection.user": "postgres",
        "connection.password": "postgres",
        "tasks.max": "1",
        "topics": "orders_spooldir_02",
        "auto.create": "true",
        "auto.evolve":"true",
        "pk.mode":"record_value",
        "pk.fields":"order_id",
        "insert.mode": "upsert",
        "table.name.format":"orders"
    }'

    //check if all connectors are running
    GET http://localhost:8083/connectors

    //Login and check into postgress
    docker exec -it postgres bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB'

    \dt
    \d orders
    select * from orders;

```

# 5.1 end to end test

    ```
    //Select a random record
    select * from orders where order_id=42;

    // Create new csv file with an updated value for this record but with the same id and retest with kafcat

    ```

# 6. Load data and create streams from KSQLDB

```
//KSQL (since it was part of original stack) already has created topics for ingested schemas in KAFKA. login to KSQL and create a new stream from ingested topic.

CREATE STREAM ORDERS WITH (KAFKA_TOPIC='orders_spooldir_02', VALUE_FORMAT='AVRO');

//  run query data from the beginning
SET 'auto.offset.reset' = 'earliest';

//run emit
SELECT * FROM ORDERS EMIT CHANGES;

```

## 6.1 Test

    ```
    //create a new data input csv with specific field change like city to 'Leeds'

    //in KSQL
    SELECT * FROM ORDERS WHERE DELIVERY_CITY='Leeds' EMIT CHANGES;

    //cp new data file to unprocessed and the resulting record should appear in ksql terminal.
    //create new stream by refactoring
    _CREATE STREAM ORDERS_LEEDS AS_ SELECT * FROM ORDERS WHERE DELIVERY_CITY='Leeds' EMIT CHANGES;

    //  aggregated data
    SELECT DELIVERY_CITY, COUNT(*) AS ORDER_COUNT, MAX(CAST(ORDER_TOTAL_USD AS DECIMAL(9,2))) AS BIGGEST_ORDER_USD FROM ORDERS GROUP BY DELIVERY_CITY EMIT CHANGES;

    //  aggregated data AS TABLE
    CREATE TABLE ORDERS_AGG_BY_CITY AS SELECT DELIVERY_CITY, COUNT(*) AS ORDER_COUNT, MAX(CAST(ORDER_TOTAL_USD AS DECIMAL(9,2))) AS BIGGEST_ORDER_USD FROM ORDERS GROUP BY DELIVERY_CITY EMIT CHANGES;

    // analytics singleton query
    SELECT ORDER_COUNT, BIGGEST_ORDER_USD FROM ORDERS_AGG_BY_CITY WHERE DELIVERY_CITY='Leeds';

    //analytics request can also be fetched from a rest api with postman or curl below
    curl -s --location --request POST 'http://localhost:8088/query' --header 'Content-type: application/json' --data-raw '{"ksql" : "SELECT ORDER_COUNT, BIGGEST_ORDER_USD FROM ORDERS_AGG_BY_CITY WHERE DELIVERY_CITY='\"Sheffield'\";","streamsProperties": {"ksql.streams.auto.offset.reset":"earliest"}}' | jq '.'


    ```

[Credits](https://www.youtube.com/watch?v=N1pseW9waNI&t=187s&ab_channel=RobinMoffatt)