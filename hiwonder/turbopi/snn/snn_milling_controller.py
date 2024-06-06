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
import threading
import numpy as np
import yaml_handle
import HiwonderSDK.Board as Board
import HiwonderSDK.mecanum as mecanum

path = '/home/pi/TurboPi/'
servo_file = 'servo_config.yaml'

# servo1 = 1500
# servo2 = 1500
target_color = ('green')

chassis = mecanum.MecanumChassis()

lab_data = None
servo_data = None


def load_config():
    global lab_data, servo_data

    lab_data = yaml_handle.get_yaml_data(yaml_handle.lab_file_path)
    servo_data = yaml_handle.get_yaml_data(yaml_handle.servo_file_path)


# Initial position
def initMove():
    current_servo_data = get_yaml_data(path + servo_file)
    servo1 = int(current_servo_data['servo1'])
    servo2 = int(current_servo_data['servo2'])
    Board.setPWMServoPulse(1, servo1, 1000)
    Board.setPWMServoPulse(2, servo2, 1000)


def get_yaml_data(yaml_file):
    file = open(yaml_file, 'r', encoding='utf-8')
    file_data = file.read()
    file.close()

    data = yaml.load(file_data, Loader=yaml.FullLoader)

    return data


# set buzzer
def setBuzzer(timer):
    Board.setBuzzer(0)
    Board.setBuzzer(1)
    time.sleep(timer)
    Board.setBuzzer(0)


range_rgb = {
    'red': (0, 0, 255),
    'blue': (255, 0, 0),
    'green': (0, 255, 0),
    'black': (0, 0, 0),
    'white': (255, 255, 255),
}

_stop = False
color_list = []
SIZE = (640, 480)
__isRunning = False
detect_color = 'None'
start_pick_up = False
draw_color = range_rgb["black"]


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
    if color == "red":
        Board.RGB.setPixelColor(0, Board.PixelColor(255, 0, 0))
        Board.RGB.setPixelColor(1, Board.PixelColor(255, 0, 0))
        Board.RGB.show()
    elif color == "green":
        Board.RGB.setPixelColor(0, Board.PixelColor(0, 255, 0))
        Board.RGB.setPixelColor(1, Board.PixelColor(0, 255, 0))
        Board.RGB.show()
    elif color == "blue":
        Board.RGB.setPixelColor(0, Board.PixelColor(0, 0, 255))
        Board.RGB.setPixelColor(1, Board.PixelColor(0, 0, 255))
        Board.RGB.show()
    else:
        Board.RGB.setPixelColor(0, Board.PixelColor(0, 0, 0))
        Board.RGB.setPixelColor(1, Board.PixelColor(0, 0, 0))
        Board.RGB.show()


# Find the contour with the largest area
# The argument is a list of contours to compare
# def getAreaMaxContour(contours):
#     contour_area_temp = 0
#     contour_area_max = 0
#     area_max_contour = None

#     for c in contours:  # Go through all contours
#         contour_area_temp = math.fabs(cv2.contourArea(c))  # Calculate contour area
#         if contour_area_temp > contour_area_max:
#             contour_area_max = contour_area_temp
#             if contour_area_temp > 300:  # The maximum area contour is only valid when the area is greater than 300 to filter interference
#                 area_max_contour = c

#     return area_max_contour, contour_area_max  # Returns the largest contour


# Robot movement logic processing
def move():
    global _stop
    global __isRunning
    global detect_color
    global start_pick_up

    while True:
        if not __isRunning:
            if _stop:
                initMove()  # Return to initial position
                _stop = False
                time.sleep(1.5)
            time.sleep(0.01)
            continue
        if detect_color != 'None' and start_pick_up:  # Color patch detected
            if detect_color == target_color:  # target color detected
                set_rgb('green')  # set rgb led to green
                chassis.set_velocity(100, 90, -0.5)  # Control robot movement function, linear speed 50 (0~100), direction angle 90 (0~360), yaw angular speed 0 (-2~2)
                time.sleep(0.05)

            else:  # if target color is not detected
                set_rgb('red')
                chassis.set_velocity(100, 90, 0.5)

            _stop = True
            start_pick_up = False
            time.sleep(0.05)

        else:
            time.sleep(0.01)
            set_rgb('red')
            chassis.set_velocity(100, 90, 0.5)


# Run child thread
th = threading.Thread(target=move)
th.daemon = True
th.start()


# Robot image processing
def run(img):
    global __isRunning
    global start_pick_up
    global detect_color, draw_color, color_list

    if not __isRunning:  # Check whether the gameplay is enabled. If not enabled, return to the original image.
        return img

    img_clean = img.copy()  # un-annotated copy of image
    # img_h, img_w = img.shape[:2]

    frame = cv2.resize(img_clean, SIZE, interpolation=cv2.INTER_NEAREST)  # resize
    frame = cv2.GaussianBlur(frame, (3, 3), 3)  # add gaussian blur
    frame = cv2.cvtColor(frame, cv2.COLOR_BGR2LAB)  # convert to LAB space

    if not start_pick_up:
        lab_threshold = (lab_data[target_color]['min'][:3], lab_data[target_color]['max'][:3])
        # mask the colors we want
        lab_threshold = [tuple(li) for li in lab_threshold]  # cast to tuple to make cv2 happy
        frame_mask = cv2.inRange(frame, *lab_threshold)
        # Perform an opening and closing operation on the mask
        # https://youtu.be/1owu136z1zI?feature=shared&t=34
        opened = cv2.morphologyEx(frame_mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        closed = cv2.morphologyEx(opened, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
        # find contours (blobs) in the mask
        contours = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)[-2]
        areas = [math.fabs(cv2.contourArea(contour)) for contour in contours]
        biggest_contour, biggest_contour_area = max(
            zip(contours, areas), key=lambda c: c[1]) if areas else (None, 0)
        if biggest_contour_area > 10:
            rect = cv2.minAreaRect(biggest_contour)
            box = np.int0(cv2.boxPoints(rect))
            cv2.drawContours(img, [box], -1, range_rgb[target_color], 2)
            detect_color = target_color
            draw_color = range_rgb[target_color]
            start_pick_up = True
        else:
            if not start_pick_up:
                detect_color = 'None'
                draw_color = range_rgb["black"]

    cv2.putText(img, "Color: " + detect_color, (10, img.shape[0] - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.65, draw_color,
                2)  # Print the detected color on the screen

    return img


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
        img = camera.frame
        if img is not None:
            frame = img.copy()
            frame2 = run(frame)
            frame_resize = cv2.resize(frame2, (320, 240))  # The screen is zoomed to 320*240
            cv2.imshow('frame', frame_resize)
            key = cv2.waitKey(1)
            if key == 27:
              break
        else:
            time.sleep(0.01)
    chassis.set_velocity(0, 0, 0)
    camera.camera_close()
    cv2.destroyAllWindows()


if __name__ == '__main__':
    main()