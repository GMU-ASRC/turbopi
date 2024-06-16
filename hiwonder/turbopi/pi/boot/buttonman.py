# from nt import stat
import os
import sys
import time
import itertools
import pathlib as pl
import json
import threading
import subprocess
# import asyncio

try:
    import psutil
    psutil = psutil
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


# BCM NUMBERING
KEY1_PIN = 13
KEY2_PIN = 23
BUZZER_PIN = 6
KDN = GPIO.LOW
KUP = GPIO.HIGH
LED1_PIN = 16
LED2_PIN = 26


def reset_wifi():
    os.system("systemctl stop hw_wifi.service > /dev/null 2>&1")
    os.system("systemctl restart wpa_supplicant.service > /dev/null 2>&1")
    os.system("systemctl restart dhcpcd.service > /dev/null 2>&1")


def start_ap():
    os.system("rm /etc/Hiwonder/* -rf > /dev/null 2>&1")
    os.system("systemctl restart hw_wifi.service > /dev/null 2>&1")


def led_setup():
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(LED1_PIN, GPIO.OUT)
    GPIO.output(LED1_PIN, 1)
    GPIO.setup(LED2_PIN, GPIO.OUT)
    GPIO.output(LED2_PIN, 0)


def try_script(path):
    if not os.path.isfile(path):
        print(f"Tried to run script but it does not exist: {path}")
        return
    if not os.access(path, os.X_OK):
        perms = 0o766
        os.chmod(path, perms)
    subprocess.Popen(path)



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
        if not isinstance(pid_info, dict):
            return None
        # return process if match, else None
        try:
            actual_process = psutil.Process(pid)
        except psutil.NoSuchProcess:
            return None
        with actual_process.oneshot():
            actual_process_info = cls.process_dict_excerpt(actual_process)
        # for compatibility with programs that don't have access to psutil
        if 'cmdline' not in pid_info or 'create_time' not in pid_info:
            pid_info.pop('cmdline', None)
            pid_info.pop('create_time', None)
            actual_process_info.pop('cmdline')
            actual_process_info.pop('create_time')
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

        record = self.read_record(fpath)  # may return error

        if (process := self.pid_matches_process(pid, record)):  # Falsy if error retrieving record
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


class PushStateMachine(statemachine.StateMachine):
    idle = statemachine.State(initial=True)
    down = statemachine.State()
    held = statemachine.State()
    rlsd = statemachine.State()
    unheld = statemachine.State()

    def __init__(self, *args, hold_period=0.35, timeout=0.45, **kwargs):
        super().__init__(*args, **kwargs)
        self.t_down = 0
        self.t_rlsd = 0
        self.hold_period = hold_period
        self.timeout = timeout
        self.short_press = lambda: None
        self.long_press = lambda: None
        self.holding = lambda: None
        self.done = lambda: None

    cycle = (down.to(held, cond='held_long_enough', after='send_hold')
           | rlsd.to(idle, cond='rlsd_long_enough', after='send_done')
         | unheld.to(idle, cond='rlsd_long_enough', after='send_done')
           | idle.to.itself(internal=True)
           | held.to.itself(internal=True)
           | down.to.itself(internal=True)
           | rlsd.to.itself(internal=True)
           | unheld.to.itself(internal=True)
    )

    pushed = (idle.to(down)
            | rlsd.to(down)
          | unheld.to(down))
    released = (down.to(rlsd, after='send_short')
              | held.to(unheld, after='send_long'))

    # quik_press = down.to(rlsd)
    # long_press = held.to(unheld)
    # holding = down.to(held)
    # done = idle.from_(unheld) | idle.from_(rlsd)

    @pushed.on
    def pushed_sideffect(self, t: int):
        self.t_down = t
        # print("pushed", t)
        # return True

    @released.on
    def released_sideffect(self, t: int):
        self.t_rlsd = t
        # return True

    def held_long_enough(self, t: int):
        return (t - self.t_down) > (self.hold_period * 1E9)

    def rlsd_long_enough(self, t: int):
        return (t - self.t_rlsd) > (self.timeout * 1E9)

    # @quik_press.after
    def send_short(self):
        # print("short press")
        self.short_press()

    # @long_press.after
    def send_long(self):
        # print("long press")
        self.long_press()

    # @holding.after
    def send_hold(self):
        # print("holding")
        self.holding()

    # @done.after
    def send_done(self):
        # print("----------------")
        self.done()

    # def after_transition(self, event: str, source: statemachine.State, target: statemachine.State, event_data):
        # print(f"Running {event} from {source!s} to {target!s}: {event_data.trigger_data.kwargs!r}")


class ActionMachine(statemachine.StateMachine):
    idle = statemachine.State(initial=True)
    invalid = statemachine.State()
    c = statemachine.State()
    cc = statemachine.State()
    ccc = statemachine.State()
    cccc = statemachine.State()
    ccccc = statemachine.State()
    cccccc = statemachine.State()
    H = statemachine.State()
    cH = statemachine.State()
    ccH = statemachine.State()
    cccH = statemachine.State()

    b2_add_c = invalid.to.itself()
    b2_add_c |= idle.to(c)
    b2_add_c |= c.to(cc)
    b2_add_c |= cc.to(ccc)
    b2_add_c |= ccc.to(cccc)
    b2_add_c |= cccc.to(ccccc)
    b2_add_c |= ccccc.to(cccccc)
    b2_add_c |= invalid.from_(cccccc, H, cH, ccH, cccH)

    b2_add_H = invalid.to.itself()
    b2_add_H |= idle.to(H, after='do_1H')
    b2_add_H |= c.to(cH, after='do_2H')
    b2_add_H |= cc.to(ccH, after='do_3H')
    b2_add_H |= ccc.to(cccH, after='do_4H')
    b2_add_H |= invalid.from_(cccc, ccccc, cccccc, H, cH, ccH, cccH)

    reset = invalid.to(idle)
    reset |= idle.from_(c, after='do_1c')
    reset |= idle.from_(cc, after='do_2c')
    reset |= idle.from_(ccc, after='do_3c')
    reset |= idle.from_(cccc, after='do_4c')
    reset |= idle.from_(ccccc, after='do_5c')
    reset |= idle.from_(cccccc, after='do_6c')
    reset |= idle.from_(H, cH, ccH, cccH)

    disable = lambda: None  # noqa: E731
    enable = lambda: None  # noqa: E731

    def do_1c(self):
        try_script("/home/pi/program1.sh")
        print("Started program1.sh")

    def do_2c(self):
        try_script("/home/pi/program2.sh")
        print("Started program2.sh")

    def do_3c(self):
        # subprocess.Popen("sudo python3 /home/pi/boot/battchk.py".split(' '))
        self.disable()
        os.system("sudo python3 /home/pi/boot/battchk.py --__listen_button_exit")
        self.enable()

    def do_4c(self):
        reset_wifi()
        led_setup()
        ButtonManager.ap_off_beep()

    def do_1H(self):
        TaskManager().close_all_registered()

    def do_2H(self):
        TaskManager().close_all_registered()
        try:
            sys.path.append('/home/pi/TurboPi/')
            import HiwonderSDK.mecanum as mecanum
            import HiwonderSDK.Board as Board
            import HiwonderSDK.Sonar as Sonar
            chassis = mecanum.MecanumChassis()
            chassis.set_velocity(0, 0, 0)
            Board.setBuzzer(0)
            s = Sonar.Sonar()
            s.setRGBMode(0)
            r, g, b = 0, 0, 0
            for i in range(2):
                Board.RGB.setPixelColor(i, Board.PixelColor(r, g, b))
                s.setPixelColor(i, Board.PixelColor(r, g, b))
            Board.RGB.show()
            s.show()
        except BaseException:
            pass

    def do_3H(self):
        subprocess.Popen("sudo python3 /home/pi/boot/hardware_test.py".split(' '))

    def do_4H(self):
        start_ap()
        ButtonManager.ap_beep()

    def do_5c(self):
        try_script("/home/pi/program5.sh")
        print("Started program5.sh")

    def do_6c(self):
        try_script("/home/pi/program6.sh")
        print("Started program6.sh")


class ButtonManager:
    beeps = True

    def __init__(self) -> None:

        GPIO.setmode(GPIO.BCM)
        GPIO.setup(KEY1_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(KEY2_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(BUZZER_PIN, GPIO.OUT)

        self.lock = threading.Lock()
        self.sequence = []
        self.serviced = True

        self.t_next = time.time_ns() + 100
        self.spin_period = 100E-3 * 1E9
        self.bouncetime = 40

        self.key1_debouncer = None
        self.key2_debouncer = None

        self.key1_sm = PushStateMachine()
        self.key2_sm = PushStateMachine()
        self.actionsm = ActionMachine()
        asm = self.actionsm
        asm.disable = self.remove_edge_listeners
        asm.enable = self.initialize_edge_listeners
        self.key2_sm.short_press = lambda: asm.send('b2_add_c')
        self.key2_sm.holding = lambda: asm.send('b2_add_H')
        self.key2_sm.done = lambda: asm.send('reset')

    @staticmethod
    def buzzer(value):
        GPIO.output(BUZZER_PIN, int(bool(value)))

    @classmethod
    def buzzfor(cls, dton, dtoff=0.0):
        cls.buzzer(1)
        time.sleep(dton)
        cls.buzzer(0)
        time.sleep(dtoff)

    def btn_event(self, channel, state):
        t = time.time_ns()
        while not self.lock.acquire_lock():  # SPINLOCK BRR
            time.sleep(0)
        self.sequence.append((channel, state, t))
        self.serviced = False
        self.lock.release()
        # print(f"Key {1 if channel == KEY1_PIN else 2} {'down' if state == KDN else 'up'}")

    def initialize_edge_listeners(self, bouncetime=None):
        print("Adding edge listeners")
        if bouncetime is None:
            bouncetime = self.bouncetime
        self.key1_debouncer = ButtonDebouncer(KEY1_PIN, self.btn_event, bouncetime=bouncetime)
        self.key2_debouncer = ButtonDebouncer(KEY2_PIN, self.btn_event, bouncetime=bouncetime)
        self.key1_debouncer.start()
        self.key2_debouncer.start()
        GPIO.add_event_detect(KEY1_PIN, GPIO.BOTH, callback=self.key1_debouncer)
        GPIO.add_event_detect(KEY2_PIN, GPIO.BOTH, callback=self.key2_debouncer)

    def remove_edge_listeners(self):
        print("Removing edge listeners")
        GPIO.remove_event_detect(KEY1_PIN)
        GPIO.remove_event_detect(KEY2_PIN)

    def bootup_check(self):
        print("Bootup period... if key 1 is held, AP mode will be set.")
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
            start_ap()
            self.ap_beep()

        self.sequence = []
        self.serviced = True
        # print(k1_held_durations)

    def wait_cycle(self):
        dt = self.t_next - time.time_ns()  # nanoseconds
        if dt > self.spin_period:
            dt = self.spin_period
        if dt < 0:
            self.t_next = time.time_ns() + self.spin_period
        else:
            time.sleep(dt * 1E-9)

    def spin(self):
        while not self.lock.acquire_lock():  # SPINLOCK BRR
            time.sleep(0)
        sequence = self.sequence.copy()
        self.sequence = []
        self.serviced = True
        self.lock.release()

        # print(sequence)

        for key, event, t in sequence:
            sm = self.key1_sm if key == KEY1_PIN else self.key2_sm
            sm.send('pushed' if event == KDN else 'released', t=t)
        now = time.time_ns()
        # if not any(key == KEY1_PIN for key, _, _ in sequence):
            # self.key1_sm.cycle(t=now)
        # if not any(key == KEY2_PIN for key, _, _ in sequence):
        self.key2_sm.cycle(t=now)

        self.wait_cycle()

    @classmethod
    def ap_beep(cls):
        cls.buzzfor(.1, .1)
        cls.buzzfor(.1, .1)
        cls.buzzfor(.1, .12)
        cls.buzzfor(.3, .2)

    @classmethod
    def ap_off_beep(cls):
        cls.buzzfor(.3, .08)
        cls.buzzfor(.08, .06)
        cls.buzzfor(.1, .13)
        cls.buzzfor(.08, .2)


if __name__ == "__main__":
    manager = ButtonManager()
    manager.bootup_check()
    manager.initialize_edge_listeners()
    try:
        subprocess.Popen("/home/pi/boot.sh")
    except FileNotFoundError:
        pass
    print('exited bootup check')
    while 1:
        manager.spin()
        # time.sleep(0)
