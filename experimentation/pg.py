import psycopg2
import os

def exec(sql):
    conn = psycopg2.connect(database="wg",
                            user='postgres', password='m1latDB',
                            host='127.0.0.1', port='35432'
                            )
    conn.autocommit = True
    cursor = conn.cursor()

    cursor.execute(sql)

    conn.commit()
    conn.close()


def gen_input(fname, is_sender, try_cnt, is_aes, is_tcp, bitrate):
    q = """insert into send (try  ,
                    strt  ,
                    stp  ,
                    t  ,
                    t_type  ,
                    tp  ,
                    tp_type ,                  
                    rt,  
                    is_sender,
                    is_aes,
                    is_tcp,
                    jitter,
                    jitter_type,
                    loss,
                    sent_packets,
                    lost_packets,
                    received_packets,
                    bitrate) values  """

    with open(fname) as f:
        for line in f:
            line = line.strip()
            if line:
                arr = line.split(" ")
                f = int(float(arr[0]))
                t = int(float(arr[1]))
                jitter = 0.0
                jitter_type = ''
                loss = 0.0
                sent_packets = 0
                lost_packets = 0
                received_packets = 0
                if t != f and t - f < 2:
                    if not is_tcp:
                        if is_sender:
                            sent_packets = int(arr[6])
                        else:
                            jitter = float(arr[6])
                            jitter_type = arr[7]
                            loss = float(arr[9].replace("(", "").replace(")", "").replace("%", "")) / 100
                            loss_parts = arr[8].split('/')
                            received_packets = int(loss_parts[1])
                            lost_packets = int(loss_parts[0])
                    q += (f"({try_cnt},"
                          f"{f},"
                          f"{t},"
                          f"{arr[2]},"
                          f"'{arr[3]}',"
                          f"{arr[4]},"
                          f"'{arr[5]}'"
                          f",{arr[6] if is_tcp and len(arr) > 6 else 0},"
                          f"{is_sender},"
                          f"{is_aes},"
                          f"{is_tcp},"
                          f"{jitter},"
                          f"'{jitter_type}',"
                          f"{loss},"
                          f"{sent_packets},"
                          f"{lost_packets},"
                          f"{received_packets},"
                          f"{bitrate}),")
                else:
                    print(line)
    return q.strip(",")


# sql3 = '''select * from send;'''
# cursor.execute(sql3)
# for i in cursor.fetchall():
#     print(i)

f1 = 'output_send_sum_all.txt'
f2 = 'output_receive_sum_all.txt'

# is_aes = False
# is_tcp = False
aes_folder = "aes"
chacha_folder = "chacha"
bitrate = 4_000_000

for is_aes in [True, False]:
    for is_tcp in [True, False]:
        for try_cnt in range(1,11):
            folder = f"./{aes_folder if is_aes else chacha_folder}/25{'_udp' if not is_tcp else ''}/{try_cnt}/sums/"
            if os.path.isdir(folder):
                exec(gen_input(f"{folder}{f1}", 1, try_cnt, 1 if is_aes else 0, 1 if is_tcp else 0,bitrate))
                exec(gen_input(f"{folder}{f2}", 0, try_cnt, 1 if is_aes else 0, 1 if is_tcp else 0,bitrate))
            else:
                print(f"Aes:{is_aes}/TCP:{is_tcp}/Try:{try_cnt} does not exists")
