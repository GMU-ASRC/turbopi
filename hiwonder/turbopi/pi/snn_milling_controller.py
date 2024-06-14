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
import json
import numpy as np
import operator
# import threading

# import yaml_handle
import HiwonderSDK.Board as Board
import HiwonderSDK.mecanum as mecanum

import casPYan
import casPYan.ende.rate as ende

network_json_path = '/home/pi/experiment_tenn2_mill20240422_1000t_n10_p100_e1000_s23.json'

neuro_tpc = 10
with open(network_json_path) as f:
    j = json.loads(f.read())
network = casPYan.network.network_from_json(j)
nodes = list(network.nodes.values())

encoders = [ende.RateEncoder(neuro_tpc, [0.0, 1.0]) for _ in range(2)]
decoders = [ende.RateDecoder(neuro_tpc, [0.0, 1.0]) for _ in range(4)]


def bool_to_one_hot(x: bool):
    return (0, 1) if x else (1, 0)


b2oh = bool_to_one_hot


def get_input_spikes(encoders, input_vector):
    input_slice = input_vector[:len(encoders)]
    return [enc.get_spikes(x) for enc, x in zip(encoders, input_slice)]
    # returns a vector of list of spikes for each node


def apply_spikes(inputs, spikes_per_node):
    for node, spikes in zip(inputs, spikes_per_node):
        node.intake += spikes


def decode_output(outputs):
    return [dec.decode(node.history) for dec, node in zip(decoders, outputs)]


# path = '/home/pi/TurboPi/'
THRESHOLD_CFG_PATH = '/home/pi/TurboPi/lab_config.yaml'
SERVO_CFG_PATH = '/home/pi/TurboPi/servo_config.yaml'


def get_yaml_data(yaml_file):
    with open(yaml_file, 'r', encoding='utf-8') as file:
        file_data = file.read()

    return yaml.load(file_data, Loader=yaml.FullLoader)


lab_data = get_yaml_data(THRESHOLD_CFG_PATH)
servo_data = get_yaml_data(SERVO_CFG_PATH)


def load_config():
    global lab_data, servo_data
    lab_data = get_yaml_data(THRESHOLD_CFG_PATH)
    servo_data = get_yaml_data(SERVO_CFG_PATH)


# servo1 = 1500
# servo2 = 1500
target_color = ('green')

chassis = mecanum.MecanumChassis()


# Initial position
def initMove():
    servo_data = get_yaml_data(SERVO_CFG_PATH)
    servo1 = int(servo_data['servo1'])
    servo2 = int(servo_data['servo2'])
    Board.setPWMServoPulse(1, servo1, 1000)
    Board.setPWMServoPulse(2, servo2, 1000)


# set buzzer
def setBuzzer(timer):
    Board.setBuzzer(0)
    Board.setBuzzer(1)
    time.sleep(timer)
    Board.setBuzzer(0)


range_bgr = {
    'red': (0, 0, 255),
    'green': (0, 255, 0),
    'blue': (255, 0, 0),
    'black': (0, 0, 0),
    'white': (255, 255, 255),
}

_stop = False
SIZE = (640, 480)
__isRunning = False


# variable reset
def reset():
    global _stop
    global color_list
    global detect_color
    global start_pick_up
    global servo1, servo2

    _stop = False
    color_list = []
    detect_color = 'None'
    start_pick_up = False
    servo1 = servo_data['servo1']
    servo2 = servo_data['servo2']


# initialization call
def init():
    print("ColorDetect Init")
    load_config()
    reset()
    initMove()


# starts run call
def start():
    global __isRunning
    reset()
    __isRunning = True
    print("ColorDetect Start")


# stops run call
def stop():
    global _stop
    global __isRunning
    _stop = True
    __isRunning = False
    chassis.set_velocity(0, 0, 0)
    set_rgb('None')
    print("ColorDetect Stop")


# exit call
def exit():
    global _stop
    global __isRunning
    _stop = True
    __isRunning = False
    set_rgb('None')
    print("ColorDetect Exit")


def setTargetColor(color):
    global target_color

    target_color = color
    return (True, ())


# Set the RGB light color of the expansion board to match the color you want to track
def set_rgb(color):
    if color not in range_bgr:
        color = "black"
    b, g, r = range_bgr[color]
    if color == "red":
        Board.RGB.setPixelColor(0, Board.PixelColor(r, g, b))
        Board.RGB.setPixelColor(1, Board.PixelColor(r, g, b))
        Board.RGB.show()


# Robot image processing
def color_contour_detection(
    frame,
    threshold: tuple[tuple[int, int, int], tuple[int, int, int]],
    open_kernel: np.array = None,
    close_kernel: np.array = None,
):
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


# Processing before closing
def manual_stop(signum, frame):
    global __isRunning

    print('Stopped')
    __isRunning = False
    initMove()  # The servo returns to the initial position


def main():
    init()
    start()
    camera = Camera.Camera()
    camera.camera_open(correction=True)  # Enable distortion correction, not enabled by default
    signal.signal(signal.SIGINT, manual_stop)
    while __isRunning:
        raw_img = camera.frame
        if raw_img is None:
            time.sleep(0.01)
            continue

        # prep a resized, blurred version of the frame for contour detection
        frame = raw_img.copy()
        frame_clean = cv2.resize(frame, SIZE, interpolation=cv2.INTER_NEAREST)
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
        threshold = (lab_data[target_color]['min'][:3], lab_data[target_color]['max'][:3])
        # run contour detection
        target_contours = color_contour_detection(
            frame_clean,
            threshold,
            **contour_args
        )
        # The output of color_contour_detection() is sorted highest to lowest
        biggest_contour, biggest_contour_area = target_contours[0] if target_contours else (None, 0)
        detected: bool = biggest_contour_area > 10  # did we detect something of interest?

        if detected:
            set_rgb('green')  # set rgb led to green
            # chassis.set_velocity(100, 90, -0.5)  # Control robot movement function
            # linear speed 50 (0~100), direction angle 90 (0~360), yaw angular speed 0 (-2~2)
        else:
            set_rgb('red')  # set rgb led to green
            # chassis.set_velocity(100, 90, 0.5)  # Control robot movement function
            # linear speed 50 (0~100), direction angle 90 (0~360), yaw angular speed 0 (-2~2)

        # breakpoint()

        spikes_per_node = get_input_spikes(encoders, b2oh(detected))
        apply_spikes(network.inputs, spikes_per_node)
        casPYan.network.run(nodes, 5)
        casPYan.network.run(nodes, neuro_tpc)
        v0, v1, w0, w1 = decode_output(network.outputs)


        v = 100 * (v1 - v0)
        w = 2.0 * (w1 - w0)

        print(v, w)

        chassis.set_velocity(v, 90, w)

        # draw annotations of detected contours
        if detected:
            draw_fitted_rect(annotated_image, biggest_contour, range_bgr[target_color])
            draw_text(annotated_image, range_bgr[target_color], target_color)
        else:
            draw_text(annotated_image, range_bgr['black'], 'None')
        frame_resize = cv2.resize(annotated_image, (320, 240))
        cv2.imshow('frame', frame_resize)
        key = cv2.waitKey(1)
        if key == 27:
            break

    chassis.set_velocity(0, 0, 0)
    camera.camera_close()
    cv2.destroyAllWindows()


if __name__ == '__main__':
    main()
