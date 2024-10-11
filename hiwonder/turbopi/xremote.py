import re
import time
import math
import json
import socket
import requests
from dataclasses import dataclass

import pygame
import numpy as np


LOBOT_PORT = 9027
RPC_PORT = 9030
RE_IDENT_HOSTNAME = re.compile(r'^(?P<model>\S+):(?P<sn>[0-9a-fA-F]{32})(?:\:(?P<hostname>\S+))?$')
RE_IP = re.compile(r'^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$')  # noqa


@dataclass
class Ident:
    """Class for keeping track of an item in inventory."""
    model: str
    sn: str
    ip: str
    port: int
    hostname: str | None = None


def discover(timeout=1):
    # get a list of all robots
    # WARNING: this is a blocking call and is not guaranteed to finish within timeout
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

    responses = {}

    def check_responses():
        data, addr = s.recvfrom(1024)
        data = str(data.strip(), 'utf-8')
        matches = RE_IDENT_HOSTNAME.match(data)
        if matches:
            d = matches.groupdict()
            ip, port = addr
            robot = Ident(d['model'], d['sn'], ip, int(port), d['hostname'])
            responses.update({d['sn']: robot})

    s.sendto(b'LOBOT_NET_DISCOVER', ('<broadcast>', LOBOT_PORT))
    s.sendto(b'LOBOT_NET_DISCOVER_HOSTNAME', ('<broadcast>', LOBOT_PORT))
    for _ in range(1024):
        try:
            check_responses()
        except TimeoutError:
            break

    ids = sorted(responses.values(), key=lambda x: x.ip)
    return ids


msg_counts = {}


def jrpc(ip: str, function: str, *args):
    url = f"http://{ip}:{RPC_PORT}/jsonrpc"
    headers = {'content-type': 'application/json'}

    msg_id = msg_counts.get(url, 0)

    payload = {
        "method": function,
        "params": args,
        "jsonrpc": "2.0",
        "id": msg_id,
    }
    response = requests.post(url, data=json.dumps(payload), headers=headers)
    response = response.json()

    msg_counts[url] = msg_id + 1

    if not response['jsonrpc']:
        raise ValueError(f"Invalid response: {response}")

    return response


class RPCRobot:
    A = 67  # mm
    B = 59  # mm
    WHEEL_DIAMETER = 65  # mm

    def __init__(self, ident):
        self.name = ident.hostname
        self.lobot_port = ident.port
        self.ip = ident.ip
        self.ident = ident
        self.a = self.A
        self.b = self.B
        self.wheel_diameter = self.WHEEL_DIAMETER
        self.velocity = 0
        self.direction = 0
        self.angular_rate = 0

    def __repr__(self):
        return repr(self.ident)

    def set_sonar_rgb(self, index, r, g, b):
        jrpc(self.ip, 'SetSonarRGB', index, r, g, b)

    def move(self, *args, **kwargs):
        self.set_velocity(*args, **kwargs)

    def stop(self):
        self.velocity = self.direction = self.angular_rate = 0
        return jrpc(self.ip, 'SetMovementAngle', -1)

    def set_velocity(self, velocity, direction, angular_rate, fake=False):
        """
        Use polar coordinates to control moving
        motor1 v1|  ↑  |v2 motor2
                 |     |
        motor3 v3|     |v4 motor4
        :param velocity: mm/s
        :param direction: Moving direction 0~360deg, 180deg<--- ↑ ---> 0deg
        :param angular_rate:  The speed at which the chassis rotates
        :param fake:
        :return:
        """
        rad_per_deg = math.pi / 180
        vx = velocity * math.cos(direction * rad_per_deg)
        vy = velocity * math.sin(direction * rad_per_deg)
        vp = -angular_rate * (self.a + self.b)
        v1 = int(vy + vx - vp)
        v2 = int(vy - vx + vp)
        v3 = int(vy - vx - vp)
        v4 = int(vy + vx + vp)
        if fake:
            return
        ret = jrpc(self.ip, 'SetBrushMotor', 1, v1, 2, v2, 3, v3, 4, v4)
        self.velocity = velocity
        self.direction = direction
        self.angular_rate = angular_rate
        return ret



def select_robot():
    print('Discovering robots...')
    robots = discover()
    print('Robots found:')
    print(*robots, sep='\n')
    s = input("Enter the robot number, hostname, or ip: ")
    s = s.strip()
    selected = None
    if s.isdigit():
        for robot in robots:  # search for hostname ending in number `s` in list
            if robot.hostname is not None and robot.hostname.split('-')[1].strip() == s:
                selected = robot
    elif RE_IP.match(s):
        for robot in robots:  # search for ip in list
            if robot.ip == s:
                selected = robot
        if selected is None:  # if ip not in list, just use the ip given.
            selected = Ident('unknown', 'unknown', s, LOBOT_PORT)
    else:
        for robot in robots:  # search for hostname in list
            if robot.hostname is not None and robot.hostname.strip().lower() == s.lower():
                selected = robot

    if selected:
        print(selected)
    else:
        print('Robot not found.')
        return -1

    return RPCRobot(selected)

    # robot.set_sonar_rgb(0, 255, 0, 0)
    # robot.move(50, 90, 1)
    # time.sleep(1)
    # robot.stop()
    # robot.set_sonar_rgb(0, *(0,) * 3)


robot = None


# This is a simple class that will help us print to the screen.
# It has nothing to do with the joysticks, just outputting the
# information.
class TextPrint:
    def __init__(self):
        self.reset()
        self.font = pygame.font.Font(None, 25)

    def tprint(self, screen, text):
        text_bitmap = self.font.render(text, True, (0, 0, 0))
        screen.blit(text_bitmap, (self.x, self.y))
        self.y += self.line_height

    def reset(self):
        self.x = 10
        self.y = 10
        self.line_height = 15

    def indent(self):
        self.x += 10

    def unindent(self):
        self.x -= 10


def test():
    pygame.init()
    # pygame.joystick.init()
    # if pygame.joystick.get_init():
    #     print("Initializing Joysticks...")


    # # Get all joysticks
    # joysticks: list[pygame.joystick.Joystick] = [pygame.joystick.Joystick(x) for x in range(pygame.joystick.get_count())]

    # # Get ID of Xbox / PS3 Controller
    # joy_id: int = 0
    # joy_found: bool = False
    # for joystick in joysticks:
    #     print(joystick.get_name())
    #     if joystick.get_name() == 'Xbox 360 Wired Controller' or joystick.get_name() == 'Microsoft X-Box 360 pad' or \
    #             joystick.get_name() == 'SHANWAN PS3 GamePad' or joystick.get_name() == 'Xbox 360 Controller':
    #         joy_id = joystick.get_id()
    #         joy_found = True
    #         break

    # if joy_found:
    #     pass
    # else:
    #     raise Exception("No Valid Joystick Found")

    # joy_cntrl = pygame.joystick.Joystick(joy_id)
    # joy_cntrl.init()

    # breakpoint()
    # Set the width and height of the screen (width, height), and name the window.
    screen = pygame.display.set_mode((500, 700))
    pygame.display.set_caption("Joystick example")

    # Used to manage how fast the screen updates.
    clock = pygame.time.Clock()

    # Get ready to print.
    text_print = TextPrint()

    # This dict can be left as-is, since pygame will generate a
    # pygame.JOYDEVICEADDED event for every joystick connected
    # at the start of the program.

    joysticks = {}
    active = {}

    done = False
    while not done:
        # Event processing step.
        # Possible joystick events: JOYAXISMOTION, JOYBALLMOTION, JOYBUTTONDOWN,
        # JOYBUTTONUP, JOYHATMOTION, JOYDEVICEADDED, JOYDEVICEREMOVED
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                done = True  # Flag that we are done so we exit this loop.

            if event.type in [pygame.JOYBUTTONDOWN, pygame.JOYAXISMOTION, pygame.JOYBALLMOTION, pygame.JOYHATMOTION]:
                if event.instance_id not in active:
                    joystick = joysticks[event.instance_id]
                    active[event.instance_id] = joystick
                    joystick.rumble(0, 0.7, 500)

            if event.type == pygame.JOYBUTTONDOWN:
                print("Joystick button pressed.")
                if event.button == 0:
                    joystick = joysticks[event.instance_id]
                    # if joystick.rumble(0, 0.7, 500):
                    #     print(f"Rumble effect played on joystick {event.instance_id}")

            if event.type == pygame.JOYBUTTONUP:
                print("Joystick button released.")

            # Handle hotplugging
            if event.type == pygame.JOYDEVICEADDED:
                # This event will be generated when the program starts for every
                # joystick, filling up the list without needing to create them manually.
                joy = pygame.joystick.Joystick(event.device_index)
                joysticks[joy.get_instance_id()] = joy
                print(f"Joystick {joy.get_instance_id()} connencted")

            if event.type == pygame.JOYDEVICEREMOVED:
                del joysticks[event.instance_id]
                del active[event.instance_id]
                print(f"Joystick {event.instance_id} disconnected")

        # Drawing step
        # First, clear the screen to white. Don't put other drawing commands
        # above this, or they will be erased with this command.
        screen.fill((255, 255, 255))
        text_print.reset()

        # Get count of joysticks.
        joystick_count = pygame.joystick.get_count()

        text_print.tprint(screen, f"Number of joysticks: {joystick_count}")
        text_print.indent()

        # For each joystick:
        for joystick in active.values():
            jid = joystick.get_instance_id()

            text_print.tprint(screen, f"Joystick {jid}")
            text_print.indent()

            # Get the name from the OS for the controller/joystick.
            name = joystick.get_name()
            text_print.tprint(screen, f"Joystick name: {name}")

            guid = joystick.get_guid()
            text_print.tprint(screen, f"GUID: {guid}")

            power_level = joystick.get_power_level()
            text_print.tprint(screen, f"Joystick's power level: {power_level}")

            # Usually axis run in pairs, up/down for one, and left/right for
            # the other. Triggers count as axes.
            axes = joystick.get_numaxes()
            text_print.tprint(screen, f"Number of axes: {axes}")
            text_print.indent()

            for i in range(axes):
                axis = joystick.get_axis(i)
                text_print.tprint(screen, f"Axis {i} value: {axis:>6.3f}")
            text_print.unindent()

            x = joystick.get_axis(0)
            y = joystick.get_axis(1)
            r = joystick.get_axis(2)
            vec = np.array([x, y])
            v = np.linalg.norm(vec)
            angle = math.degrees(np.arctan2(*vec)) + 270
            angle = angle % 360

            vel = np.interp(v, [0, 1], [0, 100])
            vel = np.clip(vel, 0, 100)
            robot.move(vel, angle, r)

            print(f"x: {x:>6.3f},\ty: {y:>6.3f},\tr: {r:>6.3f},\tv: {vel:>6.3f},\tangle: {angle:>6.3f}")



            buttons = joystick.get_numbuttons()
            text_print.tprint(screen, f"Number of buttons: {buttons}")
            text_print.indent()

            # for i in range(buttons):
            #     button = joystick.get_button(i)
            #     text_print.tprint(screen, f"Button {i:>2} value: {button}")
            # text_print.unindent()

            # hats = joystick.get_numhats()
            # text_print.tprint(screen, f"Number of hats: {hats}")
            # text_print.indent()

            # Hat position. All or nothing for direction, not a float like
            # get_axis(). Position is a tuple of int values (x, y).
            # for i in range(hats):
            #     hat = joystick.get_hat(i)
            #     text_print.tprint(screen, f"Hat {i} value: {str(hat)}")
            # text_print.unindent()

            # text_print.unindent()

        # Go ahead and update the screen with what we've drawn.
        pygame.display.flip()

        # Limit to 30 frames per second.
        clock.tick(30)
    pygame.quit()


if __name__ == '__main__':
    # main()
    robot = select_robot()
    test()
    robot.stop()
