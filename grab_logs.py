"""Zips up the logs from the robot and stores them in a timestamped folder.

This script has no options. It will prompt you to select the robots you want to grab logs from.
By default, it will grab the most recent logs from all robots online.

The script will create a folder in logs/ with the current timestamp.
Each robots' _most recent_ logs folder will be zipped up and stored in the timestamped folder.

"""


import time
import pathlib as pl

from InquirerPy import inquirer
from InquirerPy.base import Choice
from InquirerPy.separator import Separator
from xremote import discover
from ast import literal_eval
import fabric
import multiprocessing
import os

PI_LOGS_PATH = pl.PurePosixPath('/home/pi/logs')


def format_robot(ident):
    ipstr = f"({ident.ip})"
    return (
        f"{ident.hostname if ident.hostname else "[ UNKNOWN ]":>11} "
        f"{ipstr:>17} "
        f"{ident.model:>8} {ident.sn:>32}"
    )


def select_robots():
    print('Discovering robots...')
    robots = discover()
    print('Robots found:')
    print(*robots, sep='\n')
    if not robots:
        print("No robots found.")
        return []
    rdict = {robot.sn: robot for robot in robots}
    robots = [Choice(value=robot.sn, name=format_robot(robot), enabled=True) for robot in robots]
    choices = [
        Separator('     Hostname       IP Address   Model   Serial Number'),
        # Separator('012345678901234567890123456789012345678901234567890123456789'),
        *robots,
    ]
    # print(*robots, sep='\n')
    res = inquirer.checkbox(
        message=f"Select robots to grab logs from ({len(robots)} found)",
        choices=choices,
        keybindings={
            'toggle-all': [
                {'key': 'a'},
                {'key': 'c-a'},
            ],
            'skip': [{'key': 'escape'}],
        },
        long_instruction="  Select with [space], Toggle all with [a], confirm with [enter]"
    ).execute()
    return [rdict[robot] for robot in res]


def battchk(c):
    res = c.run('sudo python /home/pi/boot/battchk.py -s')
    data = res.stdout.split('\n')[0].strip()
    return literal_eval(data)


def download_logs(robot, destination):
    # print(robot)
    c = fabric.Connection(robot.ip, user='pi', connect_kwargs={'password': 'raspberry'})
    run_name = c.run(f'ls {PI_LOGS_PATH} -1t | head -n 1').stdout.strip()
    # run_dir = PI_LOGS_PATH / run_name
    c.run(f"rm -f /tmp/{run_name}.zip")
    c.run(f"cd {PI_LOGS_PATH / run_name}; zip -r /tmp/{run_name}.zip *")
    download_path = f"{destination}/{robot.hostname}-{run_name}.zip"
    c.get(f"/tmp/{run_name}.zip", download_path)
    c.run(f"rm -f /tmp/{run_name}.zip")
    # print(f"Downloaded {download_path}")
    c.close()


if __name__ == '__main__':
    res = select_robots()
    timestamp = time.strftime('%y%m%d-%H%M%S')
    logspath = pl.Path("logs")
    destination = logspath / timestamp
    destination.mkdir(exist_ok=True, parents=True)
    # single-threaded
    # for robot in res:
    #     download_logs(robot, destination)
    # multi-threaded
    with multiprocessing.Pool(processes=os.cpu_count()) as pool:
        pool.map(download_logs, ((robot, destination) for robot in res))
