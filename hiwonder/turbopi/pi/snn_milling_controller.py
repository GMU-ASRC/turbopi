#!/usr/bin/python3
# coding=utf8
# from contextlib import ExitStack
import argparse
import json
import milling_controller
from milling_controller import BinaryProgram, range_bgr

import casPYan
import casPYan.ende.rate as ende

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

network_json_path = '/home/pi/networks/experiment_tenn2_mill20240422_1000t_n10_p100_e1000_s23.json'

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


class SNNMillingProgram(BinaryProgram):
    def __init__(self,
        dry_run: bool = False,
        board=None,
        lab_cfg_path=milling_controller.THRESHOLD_CFG_PATH,
        servo_cfg_path=milling_controller.SERVO_CFG_PATH,
        pause=False,
        startup_beep=True,
        exit_on_stop=True
    ) -> None:
        super().__init__(dry_run, board, lab_cfg_path, servo_cfg_path, pause, False, exit_on_stop)

        if startup_beep:
            self.startup_beep()

    def startup_beep(self):
        self.buzzfor(.03, .05)
        self.buzzfor(.03, .05)

    def control(self):
        spikes_per_node = get_input_spikes(encoders, b2oh(self.detected))
        apply_spikes(network.inputs, spikes_per_node)
        casPYan.network.run(nodes, 5)
        casPYan.network.run(nodes, neuro_tpc)
        v0, v1, w0, w1 = decode_output(network.outputs)

        v = 100 * (v1 - v0)
        w = 2.0 * (w1 - w0)

        # print(v, w)
        self.set_rgb('green' if bool(self.detected) else 'red')
        if not self.dry_run:
            self.chassis.set_velocity(v, 90, w)


def get_parser(parser, subparser):
    return parser, subparser


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser, subparser = milling_controller.get_parser(parser, None)
    parser, subparser = get_parser(parser, None)
    args = parser.parse_args()

    program = SNNMillingProgram(dry_run=args.dry_run, pause=args.startpaused)
    program.main()
