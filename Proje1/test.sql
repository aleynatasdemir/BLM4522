-- 1. Temizlik (Her şeyi başa alma)
DROP INDEX IF EXISTS idx_taxi_pickup_datetime;
DROP INDEX IF EXISTS idx_brin_pickup;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM data_analyst, data_entry;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM data_analyst, data_entry;
REVOKE ALL PRIVILEGES ON DATABASE nyc_taxi FROM data_analyst, data_entry;
DROP ROLE IF EXISTS data_analyst;
DROP ROLE IF EXISTS data_entry;
DROP ROLE IF EXISTS db_admin;

\echo '--- 1. TABLO BOYUTU (BAŞLANGIÇ) ---'
SELECT pg_size_pretty(pg_total_relation_size('taxi_trips'));

\echo '--- 2. EXPLAIN ANALYZE (INDEKSSİZ) ---'
EXPLAIN ANALYZE
SELECT passenger_count, AVG(trip_duration) 
FROM taxi_trips 
WHERE pickup_datetime >= '2016-01-01' AND pickup_datetime < '2016-03-01'
GROUP BY passenger_count;

\echo '--- 3. B-TREE OLUŞTURMA VE SÜRE ÖLÇÜMÜ ---'
CREATE INDEX idx_taxi_pickup_datetime ON taxi_trips(pickup_datetime);
EXPLAIN ANALYZE
SELECT passenger_count, AVG(trip_duration) 
FROM taxi_trips 
WHERE pickup_datetime >= '2016-01-01' AND pickup_datetime < '2016-03-01'
GROUP BY passenger_count;

\echo '--- 4. B-TREE SİLİNİP BRIN İNDEKS OLUŞTURULMASI VE SÜRE ---'
DROP INDEX idx_taxi_pickup_datetime;
CREATE INDEX idx_brin_pickup ON taxi_trips USING BRIN(pickup_datetime);
EXPLAIN ANALYZE
SELECT passenger_count, AVG(trip_duration) 
FROM taxi_trips 
WHERE pickup_datetime >= '2016-01-01' AND pickup_datetime < '2016-03-01'
GROUP BY passenger_count;

\echo '--- 5. VACUUM ANALYZE İŞLEMİ ---'
VACUUM ANALYZE taxi_trips;

\echo '--- 6. ROLLERİN KURULMASI ---'
CREATE ROLE db_admin WITH LOGIN PASSWORD 'admin123' SUPERUSER;
CREATE ROLE data_analyst WITH LOGIN PASSWORD 'analyst123';
CREATE ROLE data_entry WITH LOGIN PASSWORD 'entry123';
GRANT CONNECT ON DATABASE nyc_taxi TO data_analyst;
GRANT USAGE ON SCHEMA public TO data_analyst;
GRANT SELECT ON taxi_trips TO data_analyst;
GRANT CONNECT ON DATABASE nyc_taxi TO data_entry;
GRANT USAGE ON SCHEMA public TO data_entry;
GRANT SELECT, INSERT ON taxi_trips TO data_entry;
