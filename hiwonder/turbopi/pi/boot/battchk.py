#!/usr/bin/python3
# coding=utf8
import sys
import signal
sys.path.append('/home/pi/TurboPi/')
sys.path.append('/home/pi/boot/')

import os
import time
import argparse

import RPi.GPIO as GPIO
import HiwonderSDK.Board as Board
import HiwonderSDK.Sonar as Sonar


import warnings
try:
    import buttonman as buttonman
    buttonman.TaskManager.register_stoppable()
except ImportError:
    buttonman = None
    warnings.warn("buttonman was not imported, so no processes can be registered. This means the process can't be stopped by buttonman.",  # noqa: E501
                  ImportWarning, stacklevel=2)


#######

environ_silent = os.environ.get('silent', None)
do_beeps = environ_silent is None or environ_silent.lower() == 'false'

if do_beeps:
    Board.setBuzzer(0)  # initialize buzzer
BUZZER_PIN = 31  # board pin numbering
KEY1_PIN = 33
KEY2_PIN = 16
KDN = GPIO.LOW
KUP = GPIO.HIGH

__stop = False
button_listen = False
button_states = [KUP, KUP]

s = Sonar.Sonar()

rgb = {
    'red': (255, 0, 0),
    'green': (0, 255, 0),
    'blue': (0, 0, 255),
    'yellow': (200, 200, 0),
    'orange': (255, 50, 0),
    'black': (0, 0, 0),
    'white': (255, 255, 255),
}

spin_period = 0.100


def waitif(t):
    n = t / spin_period
    for _ in range(int(n)):
        if __stop:
            return True
        time.sleep(spin_period)
    time.sleep(n % spin_period)
    if __stop:
        return True


def buzzer(value):
    if do_beeps:
        GPIO.output(BUZZER_PIN, int(bool(value)))


def all_leds(r, g, b):
    r, g, b = int(r), int(g), int(b)
    for i in range(2):
        Board.RGB.setPixelColor(i, Board.PixelColor(r, g, b))
        s.setPixelColor(i, Board.PixelColor(r, g, b))
    Board.RGB.show()
    s.show()


def ledbeepfor(rgbv, dton, dtoff=0.0):
    if __stop:
        return
    buzzer(1)
    all_leds(*rgbv)
    if waitif(dton):
        return
    buzzer(0)
    all_leds(*rgb['black'])
    if waitif(dtoff):
        return


def mean(li):
    return sum(li) / len(li)


def median(li):
    return sorted(li)[int(len(li) / 2)]


def voltage_detection():
    try:
        waitif(0.05)
        v = Board.getBattery() / 1000.0
        if 0 < v < 16:
            return v
    except Exception as e:
        print('Error', e)


def voltage_color(voltage: float):
    if voltage < 3.5:
        return rgb['red']
    if 3.5 <= voltage < 3.7:
        return rgb['orange']
    if 3.7 <= voltage < 3.9:
        return rgb['yellow']
    if voltage >= 3.9:
        return rgb['green']
    return (100, 0, 100)


def decimal_split(x: float, precision=1, mode='digit'):
    x = round(x, precision)
    s = f"{x:.{precision}f}"
    a, b = s.split('.')
    if mode == 'digit':
        return tuple(tuple(int(x) for x in part) for part in (a, b))
    if mode == 'whole':
        return int(a), int(b)


def beepn(n, color):
    if n == 0:
        ledbeepfor(color, .09, .2)
        return
    for _ in range(n):
        ledbeepfor(color, .3, .2)


def loop():
    measurements = [voltage_detection() for _ in range(5)]
    measurements = [x for x in measurements if x is not None]
    print(measurements)
    if not measurements:
        return
    voltage = median(measurements)
    cell = voltage / 2
    v = cell
    color = voltage_color(v)
    a, b = decimal_split(v, precision=1, mode='whole')
    print(f"{a}.{b}\t{voltage:.3f}\t{color}")
    beepn(a, color)
    if waitif(1):
        return
    beepn(b, color)
    if waitif(2.8):
        return


def stop():
    global __stop
    __stop = True
    buzzer(0)
    all_leds(*rgb['black'])
    print("battchk.py will stop soon.")
    if button_listen:
        print("Waiting for all buttons to be released...")
        return
        # while True:  # let the listener handle the exit.
        #     if not any(btn_check()):
        #         break
        #     time.sleep(0.1)
    if buttonman:
        buttonman.TaskManager.unregister()
    print("Exiting battchk.py")
    sys.exit()  # exit the python script immediately


def main():
    s.setRGBMode(0)
    for _ in range(10):
        if not __stop:
            loop()
    while __stop and button_listen and KDN in button_states:
        time.sleep(spin_period)  # trap if waiting for buttons to be unpressed...


def btn_check():
    global button_states
    button_states = [GPIO.input(KEY1_PIN), GPIO.input(KEY2_PIN)]
    return KDN in button_states


def btn_handler(channel, state):
    global button_states
    button_i = 0 if channel == KEY1_PIN else 1
    button_states[button_i] = state
    print(button_states)
    if KDN in button_states:
        stop()
        print("made it out of handler")
    elif __stop:  # both buttons are unpressed
        print("Both buttons unpressed now.")
        print("Exiting battchk.py via handler")
        if buttonman:
            buttonman.TaskManager.unregister()
        sys.exit()  # exit the python script immediately


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--__listen_button_exit', action='store_true')
    args = parser.parse_args()

    signal.signal(signal.SIGINT, lambda s, h: stop())

    button_listen = args.__listen_button_exit
    if button_listen and buttonman:
        print("Adding listeners to stop battchk.py")
        GPIO.setup(KEY1_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.setup(KEY2_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

        key1_debouncer = buttonman.ButtonDebouncer(KEY1_PIN, btn_handler, bouncetime=30)
        key2_debouncer = buttonman.ButtonDebouncer(KEY2_PIN, btn_handler, bouncetime=30)
        key1_debouncer.start()
        key2_debouncer.start()
        GPIO.add_event_detect(KEY1_PIN, GPIO.BOTH, callback=key1_debouncer)
        GPIO.add_event_detect(KEY2_PIN, GPIO.BOTH, callback=key2_debouncer)
    elif button_listen:
        raise ImportError("Requested to run in button stop mode, but buttonman module couldn't be imported! Exiting...")
    main()
