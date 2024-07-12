import sys
import time
from socket import socket, AF_INET, SOCK_DGRAM, SOL_SOCKET, SO_BROADCAST, gethostbyname, gethostname

# try:
#     from InquirerPy import inquirer as inq
# except ImportError:
#     inq = None
#     print("InquirerPy not installed. Falling back to input()")
#     print("For a nicer experience, run `pip install inquirerpy`")


# Socket code adapted from:
# https://stackoverflow.com/questions/21089268/python-service-discovery-advertise-a-service-across-a-local-network

# this needs to match info on the pi.
UDP_PORT = 27272
MAGIC = 'pi__F00#VML'  # special codeword that tells clients to listen up (and allows other programs to ignore us)


s = socket(AF_INET, SOCK_DGRAM)  # create UDP socket
s.bind(("", 0))
s.setsockopt(SOL_SOCKET, SO_BROADCAST, 1)  # this is a broadcast socket
my_ip = gethostbyname(gethostname())  # get our IP. Be careful if you have multiple network interfaces or IPs


def broadcast(cmd):
    data = f"{MAGIC}\nsender: {my_ip}\nlen: {len(cmd)}\ncmd:\n"
    data = data.encode('ascii') + cmd
    s.sendto(data, ('<broadcast>', UDP_PORT))


def start_all():
    broadcast(b"  resume")
    print("Sent >> resume <<\tcommand to all robots.")


def pause_all():
    broadcast(b"   pause")
    print("Sent >> pause <<\tcommand to all robots.")


def stop_all(deleteline=True):
    print("stopping", end='', flush=True)
    for _ in range(6):
        broadcast(b"    stop")
        print('.', end='', flush=True)
        time.sleep(0.05)
    if deleteline:
        sys.stdout.write('\033[2K\033[1G')
    else:
        print()
    print("Sent >> stop <<\tcommand to all robots.")


def quit(delprev=False):
    if delprev:
        sys.stdout.write('\033[2K\033[1G')
    print('quitting...')
    sys.exit()


def prompt(state, cmd=None, delprev=False):
    if state == 'paused':
        default = 'unpause'
    elif state == 'running':
        default = 'pause'
    else:
        default = 'stop'

    if delprev:
        sys.stdout.write('\033[2K\033[1G')

    if cmd is None:
        cmd = input(f"Enter command: {' ' * (7 - len(default))}[{default}] >>> ")
        cmd = cmd.lower().strip()

    if delprev:
        sys.stdout.write('\033[2F\033[2K\033[1G')

    if not cmd:
        cmd = default

    if cmd.startswith('u') or cmd.startswith('sta') or cmd.startswith('pl') or cmd.startswith('r') or cmd == "\\":
        start_all()
        return 'running'
    elif cmd.startswith('pa') or cmd.startswith('a'):
        pause_all()
        return 'paused'
    elif cmd.startswith('s') and cmd != 'st' or cmd == "'":
        stop_all()
        return 'stopped'
    elif cmd == 'qn' or cmd == 'quit now':
        print(f"leaving robots in {state} state")
        quit(delprev)
    elif cmd.startswith('q'):
        stop_all()
        quit(delprev)
    else:
        print("Invalid command.")
        # phelp()
        return state


def phelp():
    print("Use CTRL+C to stop all robots and quit.")
    print("Commands (not case sensitive):")
    print("    start (\\)      stop (s/')")
    print("    pause (a)      unpause / resume (u/r)")
    print("    quit now (qn)  quit (q) and stop all")


if __name__ == '__main__':
    phelp()
    print('\n\n')
    sys.stdout.write('\033[1F')
    state = 'paused'
    try:
        while True:
            state = prompt(state, delprev=True)
    except KeyboardInterrupt:
        sys.stdout.write('\033[F\033[2K\033[F\033[2K\033[1G')
        print("KeyboardInterrupt: ", end='')
        stop_all(deleteline=False)
        quit(delprev=True)
