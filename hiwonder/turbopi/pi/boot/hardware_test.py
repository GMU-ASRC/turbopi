#!/usr/bin/python3
# coding=utf8
import sys
import time
import signal

sys.path.append("/home/pi/TurboPi/")
import HiwonderSDK.Board as Board


import warnings

try:
    import buttonman as buttonman

    buttonman.TaskManager.register_stoppable()
except ImportError:
    buttonman = None
    warnings.warn(
        "buttonman was not imported, so no processes can be registered. This means the process can't be stopped by buttonman.",  # noqa: E501
        ImportWarning,
        stacklevel=2,
    )

print("""
****************PWM servo and motor test******************
----------------------------------------------------------
Official website:https://www.hiwonder.com
Online mall:https://hiwonder.tmall.com
----------------------------------------------------------
""")


def stop(sig, handler):
    chassis.set_velocity(0, 0, 0)
    set_rgb("None")
    if buttonman:
        buttonman.TaskManager.unregister()
    sys.exit()  # exit the python script immediately


signal.signal(signal.SIGINT, stop)


Board.setPWMServoPulse(1, 1800, 300)
time.sleep(0.3)
Board.setPWMServoPulse(1, 1500, 300)
time.sleep(0.3)
Board.setPWMServoPulse(1, 1200, 300)
time.sleep(0.3)
Board.setPWMServoPulse(1, 1500, 300)
time.sleep(1.5)

Board.setPWMServoPulse(2, 1200, 300)
time.sleep(0.3)
Board.setPWMServoPulse(2, 1500, 300)
time.sleep(0.3)
Board.setPWMServoPulse(2, 1800, 300)
time.sleep(0.3)
Board.setPWMServoPulse(2, 1500, 300)
time.sleep(1.5)

Board.setMotor(1, 45)
time.sleep(0.5)
Board.setMotor(1, 0)
time.sleep(1)

Board.setMotor(2, 45)
time.sleep(0.5)
Board.setMotor(2, 0)
time.sleep(1)

Board.setMotor(3, 45)
time.sleep(0.5)
Board.setMotor(3, 0)
time.sleep(1)

Board.setMotor(4, 45)
time.sleep(0.5)
Board.setMotor(4, 0)
time.sleep(1)
