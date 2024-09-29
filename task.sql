-- Вывести к каждому самолету класс обслуживания и количество мест этого класса

SELECT s.aircraft_code, s.fare_conditions, COUNT(*) AS count_seats
FROM bookings.seats s 
GROUP BY s.aircraft_code, s.fare_conditions


-- Найти 3 самых вместительных самолета (модель + кол-во мест)

SELECT a.model -> 'en' AS model, COUNT(*) AS count_seats
FROM bookings.aircrafts_data a 
	INNER JOIN bookings.seats s 
	ON a.aircraft_code = s.aircraft_code
GROUP BY a.aircraft_code
ORDER BY  count_seats DESC
LIMIT 3;

-- Вывести код, модель самолета и места не эконом класса для самолета 'Аэробус A321-200' с сортировкой по местам

SELECT a.aircraft_code, a.model -> 'ru' AS model, s.seat_no
FROM bookings.aircrafts_data a 
	INNER JOIN bookings.seats s 
	ON a.aircraft_code = s.aircraft_code
WHERE a.model ->> 'ru' = 'Аэробус A321-200' and s.fare_conditions != 'Economy' 
ORDER BY s.seat_no ASC;

-- Вывести города в которых больше 1 аэропорта ( код аэропорта, аэропорт, город)

SELECT 
	airport_code, 
	airport_name ->> 'en' AS name, 
	city->> 'en' AS city
FROM 
	bookings.airports_data 
WHERE 
	city IN (
			SELECT  a.city
			FROM bookings.airports_data a 
			GROUP BY a.city 
			HAVING  COUNT(*)>1
	);

-- Найти ближайший вылетающий рейс из Екатеринбурга в Москву, на который еще не завершилась регистрация

SELECT f. flight_id, f.scheduled_departure
FROM bookings.flights f
WHERE 
	f.departure_airport IN (		
	  	SELECT a.airport_code
		FROM bookings.airports_data a
		WHERE a.city ->> 'ru' = 'Екатеринбург'
		) 
  AND 
  	f.arrival_airport IN (
		SELECT a.airport_code
		FROM bookings.airports_data a
		WHERE a.city ->> 'ru' = 'Москва'
		)
  AND
    f.status IN ('Scheduled', 'On Time', 'Delayed')
ORDER BY f.scheduled_departure ASC
LIMIT 1


-- Вывести самый дешевый и дорогой билет и стоимость ( в одном результирующем ответе)

select t_min.ticket_no, t_min.amount AS amount_min, t_max.ticket_no, t_max.amount AS amount_max
FROM (
	SELECT tf.ticket_no, SUM(tf.amount) AS amount
	FROM bookings.ticket_flights tf
	GROUP BY tf.ticket_no
	HAVING SUM(tf.amount) = (
    						SELECT MIN(amount)
    						FROM (
       							 SELECT SUM(tf2.amount) AS amount
        						 FROM bookings.ticket_flights tf2
       							 GROUP BY tf2.ticket_no
    							) AS table1
							)
	LIMIT 1
	) as t_min 
	,
	(	
	SELECT tf.ticket_no, SUM(tf.amount) AS amount
	FROM bookings.ticket_flights tf
	GROUP BY tf.ticket_no
	HAVING SUM(tf.amount) = (
    						SELECT MAX(amount)
   							FROM (
        						SELECT SUM(tf2.amount) AS amount
       							FROM bookings.ticket_flights tf2
       							GROUP BY tf2.ticket_no
   							  ) AS table2
							)
	LIMIT 1
	) as t_max;
	
-- Вывести информацию о вылете с наибольшей суммарной стоимостью билетов

SELECT 
	f. flight_id, 
	f.flight_no, 
	max_fl.amount
FROM 
	bookings.flights f 
		INNER JOIN 
	(
	SELECT  flight_id, SUM (tf.amount) AS amount
	FROM bookings.ticket_flights tf
	GROUP BY tf.flight_id
	HAVING SUM (tf.amount)= (
						SELECT MAX(amount)
   						FROM (
        					SELECT SUM(tf2.amount) AS amount
       						FROM bookings.ticket_flights tf2
       						GROUP BY tf2.flight_id
   							  ) AS table1
						)
	) AS max_fl
		ON f.flight_id = max_fl.flight_id;



-- Найти модель самолета, принесшую наибольшую прибыль (наибольшая суммарная стоимость билетов). Вывести код модели, информацию о модели и общую стоимость

SELECT a.aircraft_code, a.model, max_sum.amount
FROM bookings.aircrafts_data a 
		INNER JOIN (
			SELECT f.aircraft_code, SUM (tf.amount) as amount 
			FROM bookings.flights f  
				INNER JOIN bookings.ticket_flights tf ON f.flight_id = tf.flight_id
			GROUP BY f.aircraft_code
			HAVING SUM (tf.amount) = (
						SELECT MAX(sum)
						FROM  (
								SELECT f.aircraft_code, SUM (tf.amount) as sum
								FROM bookings.flights f  
									INNER JOIN bookings.ticket_flights tf ON f.flight_id = tf.flight_id
								GROUP BY f.aircraft_code
							) table1
						) 

				) max_sum 	ON a.aircraft_code = max_sum.aircraft_code

-- Найти самый частый аэропорт назначения для каждой модели самолета. Вывести количество вылетов, информацию о модели самолета, аэропорт назначения, город
WITH 
madel_arrival_airport_count AS (	
	SELECT a.aircraft_code, a.model, f.arrival_airport, count(*) AS flights_count
	FROM bookings.flights f 
		INNER JOIN bookings.aircrafts_data a ON f.aircraft_code = a.aircraft_code
	GROUP BY a.aircraft_code, f.arrival_airport)
	,
model_max_flights_count AS (
	SELECT m.aircraft_code, MAX(flights_count)  AS max_flights_count
	FROM madel_arrival_airport_count m
	GROUP BY m.aircraft_code
	)	
	
SELECT t1.flights_count, t1.model, t3.airport_name, t3.city
FROM madel_arrival_airport_count t1 
	INNER JOIN model_max_flights_count t2 ON t1.flights_count= t2.max_flights_count and t1.aircraft_code = t2.aircraft_code
	INNER JOIN bookings.airports_data t3 ON t3.airport_code= t1.arrival_airport