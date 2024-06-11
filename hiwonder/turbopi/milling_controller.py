#!/usr/bin/python3
# coding=utf8
import sys

sys.path.append('/home/pi/TurboPi/')
import cv2
import time
import math
import signal
import Camera
import yaml
import numpy as np
import operator
import argparse
import timeit
# import threading

# import yaml_handle
import HiwonderSDK.Board as Board
import HiwonderSDK.mecanum as mecanum

import hiwonder_common.statistics_tools as st

# typing
from typing import Any


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
    ) -> None:
        self._stop = False
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
        self.boolean_detection_averager = st.Average(10)

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

    def stop(self):
        self.chassis.set_velocity(0, 0, 0)
        self.set_rgb('None')
        print("ColorDetect Stop")

    def set_rgb(self, color):
        # Set the RGB light color of the expansion board to match the color you want to track
        if color not in range_bgr:
            color = "black"
        b, g, r = range_bgr[color]
        self.board.RGB.setPixelColor(0, self.board.PixelColor(r, g, b))
        self.board.RGB.setPixelColor(1, self.board.PixelColor(r, g, b))
        self.board.RGB.show()

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
        target_contours = color_contour_detection(
            frame_clean,
            tuple(threshold),
            **contour_args
        )
        # The output of color_contour_detection() is sorted highest to lowest
        biggest_contour, biggest_contour_area = target_contours[0] if target_contours else (None, 0)
        detected: bool = biggest_contour_area > 10  # did we detect something of interest?

        smoothed_detected = self.boolean_detection_averager(detected)  # feed the averager

        self.set_rgb('green' if bool(smoothed_detected) else 'red')

        # print(bool(smoothed_detected), smoothed_detected)

        if not self.dry_run:
            if smoothed_detected:
                self.chassis.set_velocity(100, 90, -0.5)  # Control robot movement function
                # linear speed 50 (0~100), direction angle 90 (0~360), yaw angular speed 0 (-2~2)
            else:
                self.chassis.set_velocity(100, 90, 0.5)

        # draw annotations of detected contours
        if detected:
            draw_fitted_rect(annotated_image, biggest_contour, range_bgr[self.target_color])
            draw_text(annotated_image, range_bgr[self.target_color], self.target_color)
        else:
            draw_text(annotated_image, range_bgr['black'], 'None')
        draw_fps(annotated_image, range_bgr['black'], avg_fps)
        frame_resize = cv2.resize(annotated_image, (320, 240))
        cv2.imshow('frame', frame_resize)
        key = cv2.waitKey(1)
        if key == 27:
            return

    def main(self):
        self.init_move()
        self.camera = Camera.Camera()
        self.camera.camera_open(correction=True)  # Enable distortion correction, not enabled by default

        def loop():
            t_start = time.time_ns()
            self.main_loop()
            frame_ns = time.time_ns() - t_start
            frame_time = frame_ns / (10 ** 9)
            self.fps = 1 / frame_time
            # print(self.fps)


        while 1:
            try:
                loop()
            except KeyboardInterrupt:
                break

        self.stop()
        self.camera.camera_close()
        cv2.destroyAllWindows()


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


def draw_fitted_rect(img, contour, color):
    # draw rotated fitted rectangle around contour
    rect = cv2.minAreaRect(contour)
    box = np.int0(cv2.boxPoints(rect))
    cv2.drawContours(img, [box], -1, color, 2)


def draw_text(img, color, name):
    # Print the detected color on the screen
    cv2.putText(img, f"Color: {name}", (10, img.shape[0] - 10),
        cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)


def draw_fps(img, color, fps):
    # Print the detected color on the screen
    cv2.putText(img, f"fps: {fps:.3}", (10, 20),
        cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry_run", action='store_true')
    args = parser.parse_args()

    program = BinaryProgram(dry_run=args.dry_run)
    program.main()
