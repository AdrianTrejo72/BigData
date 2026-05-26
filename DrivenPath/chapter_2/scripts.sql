-- create table
CREATE TABLE IF NOT EXISTS bronze_layer.batch_first_load
(
    person_name character varying(100) COLLATE pg_catalog."default",
    user_name character varying(100) COLLATE pg_catalog."default",
    email character varying(100) COLLATE pg_catalog."default",
    personal_number numeric,
    birth_date character varying(100) COLLATE pg_catalog."default",
    address character varying(200) COLLATE pg_catalog."default",
    phone character varying(100) COLLATE pg_catalog."default",
    mac_address character varying(100) COLLATE pg_catalog."default",
    ip_address character varying(100) COLLATE pg_catalog."default",
    clabe character varying(100) COLLATE pg_catalog."default",
    accessed_at time without time zone,
    session_duration integer,
    download_speed integer,
    upload_speed integer,
    consumed_traffic integer,
    unique_id character varying(100) COLLATE pg_catalog."default"
)

--Revisar datos NULL...sacar script de grabacion
SELECT * FROM public.batch_first_load
WHERE person_name IS NULL OR user_name IS NULL
OR email IS NULL OR personal_number IS NULL OR birth_date IS NULL OR address IS NULL OR phone IS NULL
OR mac_address IS NULL OR ip_address IS NULL
OR clabe IS NULL OR accessed_at IS NULL OR session_duration IS NULL OR download_speed IS NULL 
OR upload_speed IS NULL OR consumed_traffic IS NULL OR unique_id IS NULL


--revisar datos duplicados
SELECT *,
COUNT(*) AS duplicated_values
FROM
bronze_layer.batch_first_load
GROUP BY (
person_name, user_name, email, personal_number,
birth_date, address, phone, mac_address, ip_address,
clabe,accessed_at, session_duration, download_speed,
upload_speed,consumed_traffic, unique_id
)
HAVING COUNT(*) > 1


--CReate dimAddress
CREATE TABLE
silver_layer.dim_address AS
SELECT
unique_id,
address,
mac_address,
ip_address
FROM bronze_layer.batch_first_load


CREATE TABLE silver_layer.dim_date AS SELECT unique_id, accessed_at FROM bronze_layer.batch_first_load

CREATE TABLE
silver_layer.dim_finance AS
SELECT
unique_id,
clabe
FROM
bronze_layer.batch_first_load

CREATE TABLE
silver_layer.dim_person AS
SELECT
unique_id,
person_name,
user_name,
email,
phone,
birth_date,
personal_number
FROM
bronze_layer.batch_first_load
 
CREATE TABLE
silver_layer.fact_network_usage AS
SELECT
unique_id,
session_duration,
download_speed,
upload_speed,
consumed_traffic
FROM
bronze_layer.batch_first_load


CREATE TABLE
	golden_layer.payment_data AS
SELECT 
	fnu.unique_id,
	df.clabe,
	fnu.download_speed,
	fnu.upload_speed,
	fnu.session_duration,
	fnu.consumed_traffic,
	((fnu.download_speed + fnu.upload_speed +1)/2) 
	+ (fnu.consumed_traffic / (session_duration + 1))
	AS payment_amount
FROM silver_layer.fact_network_usage fnu
JOIN silver_layer.dim_finance df
ON fnu.unique_id = df.unique_id


CREATE TABLE 
	golden_layer.technical_data AS
SELECT
	fnu.unique_id,
	da.address,
	da.mac_address,
	da.ip_address,
	fnu.download_speed,
	fnu.upload_speed,
	ROUND((fnu.session_duration/60),1) AS min_session_duration,
	CASE
		WHEN fnu.download_speed < 50 OR fnu.upload_speed < 30 
			OR fnu.session_duration/60 <1 THEN true
		ELSE false
	END AS technical_issue
FROM
	silver_layer.fact_network_usage fnu
JOIN 
	silver_layer.dim_address da
ON
	fnu.unique_id = da.unique_id


CREATE TABLE
	golden_layer.non_pii_data AS
SELECT
	'***MASKED***' AS person_name,
	SUBSTRING(dp.user_name, 1, 5) || '*****'  user_name,
	SUBSTRING(dp.email, 1, 5) || '*****' AS email,
	'***MASKED***'  AS personal_number, 
	'***MASKED***' AS birth_date, 
	'***MASKED***' AS address,
	'***MASKED***'  AS phone, 
	SUBSTRING(da.mac_address, 1, 5) || '*****' AS mac_address,
	SUBSTRING(da.ip_address, 1, 5) || '*****' AS ip_address,
	SUBSTRING(df.clabe, 1, 5) || '*****' AS clabe,
	dd.accessed_at,
	fnu.session_duration,
	fnu.download_speed,
	fnu.upload_speed,
	fnu.consumed_traffic,
	fnu.unique_id
FROM
	silver_layer.fact_network_usage fnu
INNER JOIN
	silver_layer.dim_address da ON fnu.unique_id = da.unique_id
INNER JOIN
	silver_layer.dim_date dd ON da.unique_id = dd.unique_id
INNER JOIN
	silver_layer.dim_finance df ON dd.unique_id = df.unique_id
INNER JOIN
	silver_layer.dim_person dp ON df.unique_id = dp.unique_id


CREATE TABLE
	golden_layer.pii_data AS
SELECT
	dp.person_name,
	dp.user_name,
	dp.email,
	dp.personal_number, 
	dp.birth_date, 
	da.address,
	dp.phone, 
	da.mac_address,
	da.ip_address,
	df.clabe,
	dd.accessed_at,
	fnu.session_duration,
	fnu.download_speed,
	fnu.upload_speed,
	fnu.consumed_traffic,
	fnu.unique_id
FROM
	silver_layer.fact_network_usage fnu
INNER JOIN
	silver_layer.dim_address da ON fnu.unique_id = da.unique_id
INNER JOIN
	silver_layer.dim_date dd ON da.unique_id = dd.unique_id
INNER JOIN
	silver_layer.dim_finance df ON dd.unique_id = df.unique_id
INNER JOIN
	silver_layer.dim_person dp ON df.unique_id = dp.unique_id