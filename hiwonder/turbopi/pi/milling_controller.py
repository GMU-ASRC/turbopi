#!/usr/bin/python3
# coding=utf8
# from contextlib import ExitStack
import sys

sys.path.append('/home/pi/TurboPi/')
sys.path.append('/home/pi/boot/')
import os
import cv2
import time
import math
import signal
import Camera
import yaml
import numpy as np
import operator
import argparse
import RPi.GPIO as GPIO
# import threading

# import yaml_handle
import HiwonderSDK.Board as Board
import HiwonderSDK.mecanum as mecanum

import hiwonder_common.statistics_tools as st

# typing
from typing import Any

import warnings
try:
    import buttonman as buttonman
    buttonman.TaskManager.register_stoppable()
except ImportError:
    buttonman = None
    warnings.warn("buttonman was not imported, so no processes can be registered. This means the process can't be stopped by buttonman.",  # noqa: E501
                  ImportWarning, stacklevel=2)


KEY1_PIN = 33  # board numbering
KEY2_PIN = 16
KDN = GPIO.LOW
KUP = GPIO.HIGH
BUZZER_PIN = 31
# path = '/home/pi/TurboPi/'
THRESHOLD_CFG_PATH = '/home/pi/TurboPi/lab_config.yaml'
SERVO_CFG_PATH = '/home/pi/TurboPi/servo_config.yaml'


def get_yaml_data(yaml_file):
    with open(yaml_file, 'r', encoding='utf-8') as file:
        file_data = file.read()

    return yaml.load(file_data, Loader=yaml.FullLoader)


range_bgr = {
    'red': (0, 0, 255),
    'green': (0, 255, 0),
    'blue': (255, 0, 0),
    'black': (0, 0, 0),
    'white': (255, 255, 255),
}


class BinaryProgram:
    def __init__(self,
        dry_run: bool = False,
        board=None,
        lab_cfg_path=THRESHOLD_CFG_PATH,
        servo_cfg_path=SERVO_CFG_PATH,
        pause=False,
        startup_beep=True,
        exit_on_stop=True
    ) -> None:
        self._run = not pause
        self.preview_size = (640, 480)

        self.target_color = ('green')
        self.chassis = mecanum.MecanumChassis()

        self.camera: Camera.Camera | None = None

        self.lab_cfg_path = lab_cfg_path
        self.servo_cfg_path = servo_cfg_path

        self.lab_data: dict[str, Any]
        self.servo_data: dict[str, Any]
        self.load_lab_config(lab_cfg_path)
        self.load_servo_config(servo_cfg_path)

        self.board = Board if board is None else board

        self.servo1: int
        self.servo2: int

        self.dry_run = dry_run
        self.fps = 0.0
        self.fps_averager = st.Average(10)
        self.detected = False
        self.boolean_detection_averager = st.Average(10)

        self.show = self.can_show_windows()
        if not self.show:
            print("Failed to create test window.")
            print("I'll assuming you're running headless; I won't show image previews.")

        GPIO.setup(KEY1_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

        if buttonman:
            self.key1_debouncer = buttonman.ButtonDebouncer(KEY1_PIN, self.btn1, bouncetime=50)
            self.key1_debouncer.start()
            GPIO.add_event_detect(KEY1_PIN, GPIO.BOTH, callback=self.key1_debouncer)

        if startup_beep:
            self.startup_beep()

        self.exit_on_stop = exit_on_stop

    def startup_beep(self):
        self.buzzfor(0.05)

    def btn1(self, channel, event):
        if event == KUP:
            if self.dry_run or not self._run:
                self.dry_run = False
                self._run = True
            else:
                self.dry_run = True
                self.kill_motors()

    @staticmethod
    def can_show_windows():
        img = np.zeros((100, 100, 3), np.uint8)
        try:
            cv2.imshow('headless_test', img)
            cv2.imshow('headless_test', img)
            key = cv2.waitKey(1)
            cv2.destroyAllWindows()
        except BaseException as err:
            if "Can't initialize GTK backend" in err.msg:
                return False
            else:
                raise
        else:
            return True

    def init_move(self):
        servo_data = get_yaml_data(SERVO_CFG_PATH)
        self.servo1 = int(servo_data['servo1'])
        self.servo2 = int(servo_data['servo2'])
        Board.setPWMServoPulse(1, self.servo1, 1000)
        Board.setPWMServoPulse(2, self.servo2, 1000)

    def load_lab_config(self, threshold_cfg_path):
        self.lab_data = get_yaml_data(threshold_cfg_path)

    def load_servo_config(self, servo_cfg_path):
        self.servo_data = get_yaml_data(servo_cfg_path)

    def kill_motors(self):
        self.chassis.set_velocity(0, 0, 0)

    def pause(self):
        self._run = False
        self.chassis.set_velocity(0, 0, 0)
        print(f"ColorDetect Paused w/ PID: {os.getpid()} Camera still open...")

    def resume(self):
        self._run = True
        print("ColorDetect Resumed")

    def stop(self):
        self._run = False
        self.chassis.set_velocity(0, 0, 0)
        if self.camera:
            self.camera.camera_close()
        self.set_rgb('None')
        cv2.destroyAllWindows()
        print("ColorDetect Stop")
        if buttonman:
            buttonman.TaskManager.unregister()
        if self.exit_on_stop:
            sys.exit()  # exit the python script immediately

    @staticmethod
    def buzzer(value):
        GPIO.output(BUZZER_PIN, int(bool(value)))

    @classmethod
    def buzzfor(cls, dton, dtoff=0.0):
        cls.buzzer(1)
        time.sleep(dton)
        cls.buzzer(0)
        time.sleep(dtoff)

    def set_rgb(self, color):
        # Set the RGB light color of the expansion board to match the color you want to track
        if color not in range_bgr:
            color = "black"
        b, g, r = range_bgr[color]
        self.board.RGB.setPixelColor(0, self.board.PixelColor(r, g, b))
        self.board.RGB.setPixelColor(1, self.board.PixelColor(r, g, b))
        self.board.RGB.show()

    def control(self):
        self.set_rgb('green' if bool(self.smoothed_detected) else 'red')
        if not self.dry_run:
            if self.smoothed_detected:
                self.chassis.set_velocity(100, 90, -0.5)  # Control robot movement function
                # linear speed 50 (0~100), direction angle 90 (0~360), yaw angular speed 0 (-2~2)
            else:
                self.chassis.set_velocity(100, 90, 0.5)

    def main_loop(self):
        avg_fps = self.fps_averager(self.fps)  # feed the averager
        raw_img = self.camera.frame
        if raw_img is None:
            time.sleep(0.01)
            return

        # prep a resized, blurred version of the frame for contour detection
        frame = raw_img.copy()
        frame_clean = cv2.resize(frame, self.preview_size, interpolation=cv2.INTER_NEAREST)
        frame_clean = cv2.GaussianBlur(frame_clean, (3, 3), 3)
        frame_clean = cv2.cvtColor(frame_clean, cv2.COLOR_BGR2LAB)  # convert to LAB space

        # prep a copy to be annotated
        annotated_image = raw_img.copy()

        # If we're calling target_contours() multiple times, some args will
        # be the same. Let's put them here to re-use them.
        contour_args = {
            'open_kernel': np.ones((3, 3), np.uint8),
            'close_kernel': np.ones((3, 3), np.uint8),
        }
        # extract the LAB threshold
        threshold = (tuple(self.lab_data[self.target_color][key]) for key in ['min', 'max'])
        # breakpoint()
        # run contour detection
        target_contours = self.color_contour_detection(
            frame_clean,
            tuple(threshold),
            **contour_args
        )
        # The output of color_contour_detection() is sorted highest to lowest
        biggest_contour, biggest_contour_area = target_contours[0] if target_contours else (None, 0)
        self.detected: bool = biggest_contour_area > 300  # did we detect something of interest?

        self.smoothed_detected = self.boolean_detection_averager(self.detected)  # feed the averager

        # print(bool(smoothed_detected), smoothed_detected)

        self.control()  # ################################

        # draw annotations of detected contours
        if self.detected:
            self.draw_fitted_rect(annotated_image, biggest_contour, range_bgr[self.target_color])
            self.draw_text(annotated_image, range_bgr[self.target_color], self.target_color)
        else:
            self.draw_text(annotated_image, range_bgr['black'], 'None')
        self.draw_fps(annotated_image, range_bgr['black'], avg_fps)
        frame_resize = cv2.resize(annotated_image, (320, 240))
        if self.show:
            cv2.imshow('frame', frame_resize)
            key = cv2.waitKey(1)
            if key == 27:
                return
        else:
            time.sleep(1E-3)

    def main(self):

        def sigint_handler(sig, frame):
            self.stop()

        def sigtstp_handler(sig, frame):
            self.pause()

        def sigcont_handler(sig, frame):
            self.resume()

        self.init_move()
        self.camera = Camera.Camera()
        self.camera.camera_open(correction=True)  # Enable distortion correction, not enabled by default

        signal.signal(signal.SIGINT, sigint_handler)
        signal.signal(signal.SIGTERM, sigint_handler)
        signal.signal(signal.SIGTSTP, sigtstp_handler)
        signal.signal(signal.SIGCONT, sigcont_handler)

        def loop():
            t_start = time.time_ns()
            self.main_loop()
            frame_ns = time.time_ns() - t_start
            frame_time = frame_ns / (10 ** 9)
            self.fps = 1 / frame_time
            # print(self.fps)

        errors = 0
        while errors < 5:
            if self._run:
                try:
                    loop()
                except KeyboardInterrupt:
                    print('Received KeyboardInterrupt')
                    self.stop()
                    break
                except BaseException as err:
                    errors += 1
                    suffix = ('th', 'st', 'nd', 'rd', 'th')
                    heck = "An" if errors == 1 else f"A {errors}{suffix[min(errors, 4)]}"
                    print(heck + " error occurred but we're going to ignore it and try again...")
                    print(err)
                    self.exit_on_stop = False
                    self.stop()
                    raise
            else:
                time.sleep(0.01)

        self.stop()

    @staticmethod
    def color_contour_detection(
        frame,
        threshold: tuple[tuple[int, int, int], tuple[int, int, int]],
        open_kernel: np.array = None,
        close_kernel: np.array = None,
    ):
        # Image Processing
        # mask the colors we want
        threshold = [tuple(li) for li in threshold]  # cast to tuple to make cv2 happy
        frame_mask = cv2.inRange(frame, *threshold)
        # Perform an opening and closing operation on the mask
        # https://youtu.be/1owu136z1zI?feature=shared&t=34
        frame = frame_mask.copy()
        if open_kernel is not None:
            frame = cv2.morphologyEx(frame, cv2.MORPH_OPEN, open_kernel)
        if close_kernel is not None:
            frame = cv2.morphologyEx(frame, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
        # find contours (blobs) in the mask
        contours = cv2.findContours(frame, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)[-2]
        areas = [math.fabs(cv2.contourArea(contour)) for contour in contours]
        # zip to provide pairs of (contour, area)
        zipped = zip(contours, areas)
        # return largest-to-smallest contour
        return sorted(zipped, key=operator.itemgetter(1), reverse=True)

    @staticmethod
    def draw_fitted_rect(img, contour, color):
        # draw rotated fitted rectangle around contour
        rect = cv2.minAreaRect(contour)
        box = np.int0(cv2.boxPoints(rect))
        cv2.drawContours(img, [box], -1, color, 2)

    @staticmethod
    def draw_text(img, color, name):
        # Print the detected color on the screen
        cv2.putText(img, f"Color: {name}", (10, img.shape[0] - 10),
            cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)

    @staticmethod
    def draw_fps(img, color, fps):
        # Print the detected color on the screen
        cv2.putText(img, f"fps: {fps:.3}", (10, 20),
            cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)


def get_parser(parser, subparser):
    parser.add_argument("--dry_run", action='store_true')
    parser.add_argument("--startpaused", action='store_true')
    return parser, subparser


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    get_parser(parser, None)
    args = parser.parse_args()

    program = BinaryProgram(dry_run=args.dry_run, pause=args.startpaused)
    program.main()
