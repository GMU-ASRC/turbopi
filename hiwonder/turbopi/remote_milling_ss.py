import socket
import threading

SERVER_IP = '0.0.0.0'
SERVER_PORT = 1555

def handle_client(conn, addr):
    print(f'Robot connected from {addr}')
    try:
        while True:
            signal = input("Enter 'start' to send START signal or 'stop' to send STOP signal: ")
            if signal == 'start' or signal == 'stop':
                conn.sendall(signal.upper().encode())
                print(f'Sent {signal.upper()} signal to {addr}')
            else:
                print("Incorrect")
    except ConnectionResetError:
        print("failed")
    finally:
        conn.close()

def server():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((SERVER_IP, SERVER_PORT))
        s.listen()
        print('Server listening for connections...')

        while True:
            conn, addr = s.accept()
            client_thread = threading.Thread(target=handle_client, args=(conn, addr))
            client_thread.start()

if __name__ == '__main__':
    server()
