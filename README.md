# GMU-ASRC/turbopi

This repository contains scripts and models for the **Hiwonder TurboPi** robot.

GMU's [ASRC](https://github.com/GMU-ASRC) uses the TurboPi robot as a platform 
for testing and developing emergent behaviors in **swarm robotics**.

This repository only contains **scripts for managing the robot**. Nothing from this repo should go onto an actual Turbopi robot.

-----

Part of the GMU-ASRC TurboPi cinematic universe:
* [Provision](https://github.com/GMU-ASRC/turbopi-provision)
* [Driver](https://github.com/GMU-ASRC/turbopi-driver)
* [Core Services](https://github.com/GMU-ASRC/turbopi-coreservices)

Research-related (not installed by main branch provision scripts):
* [TurboPi Main Page management and simulations](https://github.com/GMU-ASRC/turbopi) (You are here)
* [Managed Home Directory](https://github.com/GMU-ASRC/turbopi-root)


<b> Link to the [wiki](https://github.com/GMU-ASRC/turbopi/wiki) </b>

-----

# TurboPi

<img width="300" alt="clean_low_DSC7819" src="https://github.com/user-attachments/assets/b194a3be-7b30-4c84-8ab5-736ce5f86894" />

The [Hiwonder TurboPi](https://www.hiwonder.com/products/turbopi?variant=42513906860119) is a ~300 USD 4-wheeled mecanum robot which we use in our swarms research.
It is equipped with a camera as its primary sensor, but it also has an ultrasonic sensor and line following sensor.
Notably, it does not have wheel encoders.

It is equipped with a Raspberry Pi; our lab uses the Raspberry Pi 4b 4GB variant running Raspberry Pi OS 13. Though Hiwonder make ROS images for the robot, we do not use ROS.

For more information on the TurboPi, see:
* Our [wiki](https://github.com/GMU-ASRC/turbopi/wiki)
* Our API documentation (coming soon, refer to docstrings in the other repos for now)
* [Hiwonder's docs and SDK](https://docs.hiwonder.com/projects/TurboPi/en/advanced/docs/1.getting_ready.html) (may not apply to our software image)



# Directory Structure

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
