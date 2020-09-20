# Идея
###

Сдампить все свои gps записи активности с Strava и получить персональный heatmap
https://www.strava.com/heatmap

# TO DO
###

- gpx файлы с Strava выгружены (https://support.strava.com/hc/en-us/articles/216918437-Exporting-your-Data-and-Bulk-Export)
- Поставить clickhouse поиграться
- Разобраться с доступом до clickhouse-server (HTTP?)
- Разобраться с экспортом данных в формат для загрузки в базу clickhouse (в идеале python)
- Решить с форматом таблицы БД clickhouse
- Посмотреть API google/yandex карт, и решить, что можно использовать
- Подумать о визуализации данных в БД (~ 2млн координат)


# LOG
###

Поставил clickhouse в докере
```
$ mkdir $HOME/clickhouse_test_db
$ docker run -d --name some-clickhouse-server --ulimit nofile=262144:262144 --volume=$HOME/clickhouse_test_db:/var/lib/clickhouse yandex/clickhouse-server 
```
Клиент пока там же
```
$ docker run -it --rm --link some-clickhouse-server:clickhouse-server yandex/clickhouse-client --host clickhouse-server
```

База и таблица пока такие
```
CREATE DATABASE gpx;
Use gpx;

CREATE TABLE trips
(
point_datetime DateTime,
point_longitude Float64,
point_latitude Float64,
point_elevation Float64
) ENGINE = MergeTree
PARTITION BY toYYYYMM(point_datetime) 
ORDER BY (point_longitude, point_latitude) 
```
Не уверен в движке таблицы и ключах сортировки.
Читать про движки тут https://clickhouse.tech/docs/ru/engines/table-engines/mergetree-family/mergetree/

Тест единичной записью
```
INSERT INTO trips Values ('2020-01-01 00:00:00', 57.9921901, 56.2471849, 156.8)
```