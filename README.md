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
$ docker run -d --name gpx-clickhouse-server --ulimit nofile=262144:262144 --volume=$HOME/clickhouse_test_db:/var/lib/clickhouse -p 8123:8123 -p 9000:9000 yandex/clickhouse-server 
```
Клиент пока там же
```
$ docker run -it --rm --link gpx-clickhouse-server:clickhouse-server yandex/clickhouse-client --host clickhouse-server
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
Можно дёргать инфу через HTTP
```
echo 'SELECT * from gpx.trips' | curl 'http://localhost:8123/?query=' --data-binary @-
2020-01-01 00:00:00	57.9921901	56.2471849	156.8
```

Кастельно загрузки данных в БД, Филонов из БКС использовал такую конструкцию, то есть TabSeparated
```
nf2nat -l -r $F -o $DST -t  | xin  -l 400000 -e POST 'http://flower3:8123/?database=nel&query=insert%20into%20natdata%20FORMAT%20TabSeparated'  && rm $P/nfcapd$D
```
https://clickhouse.tech/docs/ru/interfaces/formats/ - форматы ввода/вывода
xin - софтинка, Xin reads from standard input splitting the data up into sections. Each section is piped into a command separately.
http://www.kyne.com.au/~mark/software.html


KISS линупсовый. Формат даты только кривой.
Можно в таблице DateTime64.
```
xml2 < 1880151519.gpx | 2csv trkpt time @lat @lon ele
2018-08-05T15:20:29.999Z,57.99231,56.24651,171
2018-08-05T15:20:30.999Z,57.99231,56.24651,171
2018-08-05T15:20:31.999Z,57.99231,56.24651,171
```
Впилил импорт данных через XML->CSV и загрузку через clickhouse-client
```
find ./ -iname "*.gpx" -exec ./xml2csv.sh {} \; > full.csv
sed -i 's/Z//g' full.csv
docker run --link gpx-clickhouse-server:clickhouse-server -i yandex/clickhouse-client --host clickhouse-server --query="INSERT INTO gpx.trips FORMAT CSV" < ./full.csv
```

Интересно проверить работу PARTITION
```
SELECT 
    partition,
    name,
    active
FROM system.parts
WHERE table = 'trips'
```
