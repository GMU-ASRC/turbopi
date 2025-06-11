# GMU-ASRC/turbopi
This repository contains scripts and models for the **Hiwonder TurboPi** robot.

This repository only contains **scripts for managing the robot**. Code for the 
robot is in the [turbopi-root](https://github.com/GMU-ASRC/turbopi-root) repository.

GMU's [ASRC](https://github.com/GMU-ASRC) uses the TurboPi robot as a platform 
for testing and developing emergent behaviors in **swarm robotics**.

### Link to the [wiki](https://github.com/GMU-ASRC/turbopi/wiki)

## Directory Structure

```
┬
├── logs/           # Put logs from turbopis here for use with graphing scripts
├── nlogo/          # NetLogo models for the robot
├──┬pi/             # Submodule for pi home directory
│  └── ...          #   This is a submodule. See the turbopi-root repo for more info.
├── scripts/        # Shell scripts for installing and updating the robot
│
├── TurboPi_Actuation_tests.xlsx  # Google sheets download of the actuation tests
├── actuation_modelling.ipynb  # Jupyter notebook for modelling actuation
├── graph_tsv.py    # Graph actuation data from a log file
├── pid.py          # Dependency for statistics_tools.py
├── remote_switcher.py  # cmd-line tool for sending UDP stop/start/mode-switch commands
├── test_client.py  # View UDP broadcast packets for debugging
└── xremote.py      # Control a robot with a game controller
```
