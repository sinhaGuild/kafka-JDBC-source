curl -i -X PUT -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:8083/connectors/pokemon-source-csv-spooldir-00/config \
    -d '{
            "connector.class": "com.github.jcustenborder.kafka.connect.spooldir.SpoolDirCsvSourceConnector",
            "topic": "pokemon_spooldir_02",
            "input.path": "/data/gyan/unprocessed",
            "finished.path": "/data/gyan/processed",
            "error.path": "/data/gyan/error",
            "input.file.pattern": ".*\\.csv",
            "schema.generation.enabled":"true",
            "schema.generation.key.fields":"pokedex_number",
            "csv.first.row.as.header":"true",
            "transforms":"castTypes",
            "transforms.castTypes.type":"org.apache.kafka.connect.transforms.Cast$Value",
            "transforms.castTypes.spec":"pokedex_number:int32,speed:int32,weight_kg:float32"
        }'

curl --silent --location --request GET 'http://localhost:8081/subjects/pokemon-source-csv-spooldir-00/versions/latest' |jq '.schema|fromjson'

curl -X PUT http://localhost:8083/connectors/sink-postgres-pokemon-00/config \
    -H "Content-Type: application/json" \
    -d '{
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "connection.url": "jdbc:postgresql://postgres:5432/",
        "connection.user": "postgres",
        "connection.password": "postgres",
        "tasks.max": "1",
        "topics": "pokemon_spooldir_02",
        "auto.create": "true",
        "auto.evolve":"true",
        "pk.mode":"record_value",
        "pk.fields":"pokedex_number",
        "insert.mode": "upsert",
        "table.name.format":"pokemon" }'


CREATE STREAM POKEMON WITH(KAFKA_TOPIC='pokemon_spooldir_02',VALUE_FORMAT='AVRO');

CREATE TABLE POKEMON_STATS AS SELECT CLASSFICATION, AVG(WEIGHT_KG) AS AVG_WEIGHT, AVG(SPEED) AS SPEED FROM POKEMON GROUP BY CLASSFICATION EMIT CHANGES;