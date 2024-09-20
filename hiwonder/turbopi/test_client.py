from socket import socket, AF_INET, SOCK_DGRAM

PORT = 27272
MAGIC = b'pi__F00#VML'  # to make sure we don't confuse or get confused by other programs

sock = socket(AF_INET, SOCK_DGRAM)  # create UDP socket
sock.bind(('', PORT))

try:
    while 1:
        data, addr = sock.recvfrom(1024)  # wait for a packet
        if data.startswith(MAGIC):
            msg = data.split(b'cmd:\n', 1)
            print(f"####### {addr}")
            print(msg[0].decode('ascii'))
            print("---")
            try:
                print(msg[1].strip())
            except IndexError:
                pass
except KeyboardInterrupt:
    raise