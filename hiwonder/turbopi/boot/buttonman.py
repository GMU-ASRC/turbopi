# from nt import stat
import os
import sys
import time
import itertools
import pathlib as pl
import json
import threading
# import asyncio

try:
    import psutil
except ImportError:
    psutil = None
try:
    import statemachine
except ImportError:
    statemachine = None



import RPi.GPIO as GPIO

# typing
from typing import Any


PID_DIR = "/tmp/buttonman"


# polyfill for 3.9 < 3.10
if 'pairwise' in dir(itertools):
    pairwise = itertools.pairwise
else:
    def pairwise(iterable):
        # pairwise('ABCDEFG') → AB BC CD DE EF FG
        iterator = iter(iterable)
        a = next(iterator, None)
        for b in iterator:
            yield a, b
            a = b


KEY1_PIN = 13
KEY2_PIN = 23
KDN = GPIO.LOW
KUP = GPIO.HIGH


def reset_wifi():
    os.system("rm /etc/Hiwonder/* -rf > /dev/null 2>&1")
    os.system("systemctl restart hw_wifi.service > /dev/null 2>&1")


class ProcessMismatchError(Exception):
    pass


class TaskManager:
    def __init__(self, pid_dir=None):
        self.pid = os.getpid()
        self.pid_dir = pl.Path(PID_DIR)

        if pid_dir is None:
            pid_dir = PID_DIR
        listing_path = pl.Path(pid_dir)
        listing_path.mkdir(parents=False, exist_ok=True)  # raise error if /tmp does not exist

    @staticmethod
    def process_dict_excerpt(p: psutil.Process):
        if p is int:
            p = psutil.Process(p)
        with p.oneshot():
            return {
                'pid': p.pid,
                'name': p.name(),
                'username': p.username(),
                'cmdline': p.cmdline(),
                'create_time': p.create_time()
            }

    @classmethod
    def register_stoppable(cls, pid_dir=None):
        # Run this from within your program to register it to buttonman.
        if pid_dir is None:
            pid_dir = PID_DIR
        listing_path = pl.Path(pid_dir)
        listing_path.mkdir(parents=False, exist_ok=True)  # raise error if /tmp does not exist
        # Note: /tmp is probably guaranteed to exist on POSIX, but sysadmins may choose a different $TMPDIR.
        # See both top answers here: https://unix.stackexchange.com/questions/362100/is-tmp-guaranteed-to-exist
        # We're targeting Raspberry Pi though so who cares.
        pid = os.getpid()
        self_infofile = listing_path / f'{pid}'
        selfp = psutil.Process(pid)
        with selfp.oneshot():
            info = cls.process_dict_excerpt(selfp)
        info_str = json.dumps(info) + '\n'
        self_infofile.write_text(info_str)  # OVERWRITES EXISTING!
        # equivalent to opening in 'w' mode; writing; closing.

    @classmethod
    def unregister(cls, pid_dir=None, check_match=True):
        # Run this from within your program to unregister it from buttonman.
        # Only deletes file if it matches the current process info.
        if pid_dir is None:
            pid_dir = PID_DIR
        listing_path = pl.Path(pid_dir)
        pid = os.getpid()
        infofile = listing_path / f'{pid}'
        record = cls.read_record(infofile)
        if (not check_match
            or cls.pid_matches_process(pid, record)):
            infofile.unlink(missing_ok=True)

    @classmethod
    def pid_matches_process(cls, pid, pid_info):
        # return process if match, else None
        try:
            actual_process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            return None
        with actual_process.oneshot():
            actual_process_info = cls.process_dict_excerpt(actual_process)
        if actual_process_info == pid_info:
            return actual_process

    @staticmethod
    def read_record(path):
        path = pl.Path(path)
        # try to load the record as dict from json
        try:
            txt: str = path.read_text()
            record: dict[str, Any] = json.loads(txt)
            return record
        except json.JSONDecodeError as err:
            return err
        except FileNotFoundError as err:
            return err

    def close_registered(self, pid: int, timeout=5, ignore_nonexistent=False):
        # attempt to close the process if it matches its registration.
        # Can return FileNotFoundError, JSONDecodeError
        # If timeout is positive, then it will wait for the process to terminate, and will be killed if the timeout elapses.
        # Otherwise, termination will only be attempted and the process will be returned so you can check on it.
        # If ignore_nonexistent is False (default), FileNotFoundError is RAISED if the process record can't be found.
        # All other errors are raised.
        # If the process is terminated successfully, the return code or -signal is returned. (see comment below)
        fpath = self.pid_dir / str(pid)
        if not fpath.exists() and ignore_nonexistent:
            try:
                open(fpath)
            except FileNotFoundError as err:
                return err

        def delete_record():
            fpath.unlink(missing_ok=True)

        record = self.read_record(fpath)
        if not isinstance(record, dict):
            return record  # likely got an error if here.

        if (process := self.pid_matches_process(pid, record)):
            process.terminate()  # ask nicely
            # if timeout is valid, BLOCK, wait, and then kill.
            if isinstance(timeout, (float, int)) and timeout > 0:
                try:
                    result = process.wait(timeout=timeout)
                except psutil.TimeoutExpired:
                    result = process.kill()  # not asking nicely anymore
                delete_record()
                return result  # https://psutil.readthedocs.io/en/latest/#psutil.Process.wait
            else:  # if no timeout, return immediately.
                return process, fpath
        else:
            delete_record()
            return ProcessMismatchError(f"Process does not match stored process registration record. Process not terminated. pid: {pid}")  # noqa: E501

    def close_all_registered(self, processes=1):
        attempts = []
        for child in self.pid_dir.iterdir():
            # exclude directories and .dotfiles
            if not child.is_file() or child.name.startswith('.'):
                continue
            # exclude file names that don't look like ints
            try:
                pid = float(child.name)
                if pid == int(pid):
                    pid = int(pid)
                else:
                    raise ValueError
            except ValueError:
                continue
            # attempt to terminate.
            attempts.append(self.close_registered(pid, timeout=-1))
        results = [x for x in attempts if isinstance(x, tuple)]
        processes = [process for process, path in results]
        # force kill the remaining ones.
        gone, alive = psutil.wait_procs(processes, timeout=10)
        for process, path in results:
            if process in alive:
                process.kill()
            path.unlink(missing_ok=True)
        return gone, alive


# adapted from https://raspberrypi.stackexchange.com/a/76738/63335
class ButtonDebouncer(threading.Thread):
    def __init__(self, pin, func=None, edge=GPIO.BOTH, bouncetime=200):
        super().__init__(daemon=True)

        def nop(*args):
            pass

        self.edge = edge
        self.func = nop if func is None else func
        self.pin = pin
        self.bouncetime = bouncetime / 1000

        self.lastpinval = GPIO.input(self.pin)
        self.lock = threading.Lock()

    def __call__(self, *args):
        if not self.lock.acquire(blocking=False):
            return

        t = threading.Timer(self.bouncetime, self.read, args=args)
        t.start()

    def read(self, *args):
        pinval = GPIO.input(self.pin)

        if (
            self.edge == GPIO.BOTH and pinval != self.lastpinval
            or self.edge == GPIO.FALLING and (pinval == 0 and self.lastpinval == 1)
            or self.edge == GPIO.RISING and (pinval == 1 and self.lastpinval == 0)
        ):
            self.func(args[0], pinval)

        self.lastpinval = pinval
        self.lock.release()


class ButtonManager:
    def __init__(self) -> None:

        GPIO.setmode(GPIO.BCM)
        GPIO.setup(KEY1_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(KEY2_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)


        self.lock = threading.Lock()
        self.sequence = []
        self.serviced = True

        self.t_next = time.time_ns() + 100
        self.spin_period = 100E-3 * 1E9

        self.key1_debouncer = ButtonDebouncer(KEY1_PIN, self.btn_event, bouncetime=50)
        self.key2_debouncer = ButtonDebouncer(KEY2_PIN, self.btn_event, bouncetime=50)

    def btn_event(self, channel, state):
        t = time.time_ns()
        while not self.lock.acquire_lock():  # SPINLOCK BRR
            time.sleep(0)
        self.sequence.append((channel, state, t))
        self.serviced = False
        self.lock.release()
        print(f"Key {1 if channel == KEY1_PIN else 2} {'down' if state == KDN else 'up'}")

    def initialize_edge_listeners(self, bouncetime=50):
        self.key1_debouncer = ButtonDebouncer(KEY1_PIN, self.btn_event, bouncetime=bouncetime)
        self.key2_debouncer = ButtonDebouncer(KEY2_PIN, self.btn_event, bouncetime=bouncetime)
        self.key1_debouncer.start()
        self.key2_debouncer.start()
        GPIO.add_event_detect(KEY1_PIN, GPIO.BOTH, callback=self.key1_debouncer)
        GPIO.add_event_detect(KEY2_PIN, GPIO.BOTH, callback=self.key2_debouncer)

    def remove_edge_listeners(self):
        GPIO.remove_event_detect(KEY1_PIN)
        GPIO.remove_event_detect(KEY2_PIN)

    def bootup_check(self):
        self.initialize_edge_listeners(45)

        if not self.sequence and GPIO.input(KEY1_PIN) == KDN:
            self.sequence = [(KEY1_PIN, KDN, time.time_ns())]
            print("key 1 already down")
        # if not self.sequence and GPIO.input(KEY2_PIN) == KDN:
        #     self.sequence = [(KEY2_PIN, KDN, time.time_ns())]

        time.sleep(6)

        # stop listening
        self.remove_edge_listeners()

        # if the button is still held down, add a corresponding up entry
        if GPIO.input(KEY1_PIN) == KDN:
            self.sequence.append((KEY1_PIN, KUP, time.time_ns()))
        # if GPIO.input(KEY2_PIN) == KDN:
        #     self.sequence.append((KEY2_PIN, KUP, time.time_ns()))

        # filter out each key in the sequence
        k1_seq = [x for x in self.sequence if x[0] == KEY1_PIN]
        # k2_seq = [x for x in self.sequence if x[0] == KEY2_PIN]

        def key_held_durations(sequence):
            lengths = []
            for a, b in pairwise(sequence):
                _, a_s, a_t = a
                _, b_s, b_t = b
                if not (a_s == KDN and b_s == KUP):
                    continue
                if b_t < a_t:
                    print("Congrats, you've created a time machine.")
                    continue
                dt = b_t - a_t
                lengths.append(dt)
            return lengths

        k1_held_durations = key_held_durations(k1_seq)  # durations in nanoseconds (ns)
        if any(t > 4E9 for t in k1_held_durations):  # if key 1 was held for longer than 4 seconds
            print("wifi reset triggered")
            # reset_wifi()

        self.serviced = True
        # print(k1_held_durations)

    def wait_cycle(self):
        dt = self.t_next - time.time_ns()  # nanoseconds
        if dt > self.spin_period:
            dt = self.spin_period
        if dt < 0:
            self.t_next = time.time_ns() + self.spin_period
        time.sleep(dt * 1E-9)

    def spin(self):
        while not self.lock.acquire_lock():  # SPINLOCK BRR
            time.sleep(0)
        sequence = self.sequence.copy()
        self.serviced = True
        self.lock.release()
        pass


    # key1_pressed = False
    # key2_pressed = False
    # count = 0
    # while True:
    #     if GPIO.input(KEY1_PIN) == GPIO.LOW:
    #         time.sleep(0.05)
    #         if GPIO.input(KEY1_PIN) == GPIO.LOW:
    #             if key1_pressed == True:
    #                 count += 1
    #                 servo_test = True
    #                 if count == 60:
    #                     count = 0
    #                     servo_test = False
    #                     key1_pressed = False
    #                     print('reset_wifi')
    #                     reset_wifi()
    #         else:
    #             count = 0
    #             continue

    #     elif GPIO.input(KEY2_PIN) == GPIO.LOW:
    #         time.sleep(0.05)
    #         if GPIO.input(KEY2_PIN) == GPIO.LOW:
    #             if key2_pressed == True:
    #                 count += 1
    #                 if count == 60:
    #                     count = 0
    #                     key2_pressed = False
    #                     print('sudo halt')
    #                     os.system('sudo halt')
    #         else:
    #             count = 0
    #             continue
    #     else:
    #         if servo_test:
    #             # servo_test = False
    #             # os.system("sudo python3 /home/pi/TurboPi/HiwonderSDK/hardware_test.py")
    #             os.system("sudo python3 /home/pi/Binary_Control.py")

    #         count = 0
    #         if not key1_pressed:
    #             key1_pressed = True
    #         if not key2_pressed:
    #             key2_pressed = True
    #         time.sleep(0.05)



if __name__ == "__main__":
    manager = ButtonManager()
    manager.bootup_check()
    print('exited bootup check')
    while 1:
        time.sleep(0)
