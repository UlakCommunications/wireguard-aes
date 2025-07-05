--create database wg;
\c wg;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE send(try int NULL,
                  strt int NOT NULL,
                  stp int NOT null,
                  t float NOT NULL,
                  t_type varchar(30),
                  tp float NOT NULL,
                  tp_type varchar(30),
                  rt  int NOT NULL,
                  is_sender  int NOT NULL,
                  is_aes  int NOT NULL,
                  is_tcp  int NOT NULL,
                  jitter  float8 NOT NULL,
                  jitter_type  varchar(30) NOT NULL,
                  loss  float8 NOT NULL,
                  sent_packets  int NOT NULL,
                  lost_packets  int NOT NULL,
                  received_packets  int NOT NULL,
                  bitrate  int NOT NULL);

CREATE TABLE public.enc_perf (
             algorithm varchar NOT NULL,
             blocksize int NOT NULL,
             thruoughput float8 NOT NULL
);

insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-128-GCM',16,30.3);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-128-GCM',256,432.7);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-128-GCM',1350,1651.5);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-128-GCM',8192,3772.1);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-128-GCM',16384,4232.3);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-256-GCM',16,30.3);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-256-GCM',256,371.3);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-256-GCM',1350,1404.2);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-256-GCM',8192,2634.1);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('AES-256-GCM',16384,3040.8);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('ChaCha20-Poly1305',16,60.3);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('ChaCha20-Poly1305',256,671.5);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('ChaCha20-Poly1305',1350,1217.5);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('ChaCha20-Poly1305',8192,1658.6);
insert into enc_perf (algorithm, blocksize, thruoughput) values ('ChaCha20-Poly1305',16384,1670);

CREATE EXTENSION IF NOT EXISTS tablefunc;


