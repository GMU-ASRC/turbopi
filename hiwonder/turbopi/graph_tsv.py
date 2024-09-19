import argparse
import pandas as pd
from matplotlib import pyplot as plt
import pathlib
import colorsys
import itertools
from ast import literal_eval as eval

try:
    from hiwonder_common import project
except ImportError:
    try:
        import sys
        path = pathlib.Path("pi/hiwonder_common/src")
        sys.path.append(str(path.resolve()))
        import hiwonder_common.project as project
    except ImportError:
        print("hiwonder_common not found. Certain features will not work.")
        project = None


def hr(h, s, l):  # noqa: E741
    return colorsys.hls_to_rgb(h, l, s)


def graph(data):
    plt.rcParams["figure.figsize"] = [7.00, 3.50]
    plt.rcParams["figure.autolayout"] = True
    # read the csv files using pandas excluding the timedate column
    # df = df.drop(columns=['time'], axis=1)
    cr = hr(0.0, 0.9, 0.4)
    cb = hr(0.6, 0.9, 0.4)
    cg = hr(0.3, 0.9, 0.4)

    fig, ax = plt.subplots()
    ax.cla()

    def get_last_move(moves):
        try:
            return moves[-1]
        except IndexError:
            return float('nan')

    times = data.iloc[:, 0]
    ts = times.copy() - times[0]
    if ts.name.strip().lower() == 'time_ns':
        ts /= 1e9

    breakpoint()
    moves = data.iloc[:, -1]
    moves = moves.apply(eval)
    moves = moves.apply(get_last_move)
    moves = moves.apply(pd.Series, index=['v', 'd', 'w'])

    if not moves['v'].empty:
        # Plot the velocity
        ax.plot(ts, moves['v'], label="Velocity", color="blue", alpha=0.5, linestyle="-")

    if not moves['w'].empty:
        # Plot the turn rate
        axw = ax.twinx()
        axw.plot(ts, moves['w'], label="Turn Rate", color="red", alpha=0.5, linestyle="-")

    inputs = data.iloc[:, 1:-1]
    sense = None
    if not inputs.empty:
        # create green vertical spanning regions for sensors
        sense = inputs.iloc[:, -1]
        xsen = [ts[0]] if not sense.empty and sense[0] else []
        xnot = []
        for (xi, si), (xn, sn) in itertools.pairwise(zip(ts, sense)):
            if sn > si:
                xsen.append(xn)
            if si > sn:
                xnot.append(xi)
        if not sense.empty and sense.iloc[-1]:
            xnot.append(len(sense) - 1)

        # breakpoint()
        # Plot the binary detection
        # ax.plot(ts, sense, label=sense.name, color="blue", linestyle="-", marker="o")
        ax.plot(ts, sense, c=cg, label=sense.name, alpha=0.1)
        # if plot_state:
        #     ax.subplot(111, aspect='equal')
        for xa, xb in zip(xsen, xnot):
            ax.axvspan(xa, xb, ymin=0.0, ymax=1.0, alpha=0.15, color='green')

    # Labels and Title
    plt.xlabel("Time (seconds)")
    plt.ylabel("Output Values")
    plt.title("Output Values over Time")
    plt.legend()
    plt.grid(True)
    plt.show()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("filename", type=pathlib.Path, help="csv file to be graphed")
    args = parser.parse_args()

    if project and not args.filename.is_file():
        p = project.make_default_project(args.filename, root='logs')
        filename = p.root / 'io.tsv'
    else:
        filename = args.filename

    sep = '\t' if filename.suffix == '.tsv' else ','
    data = pd.read_csv(filename, sep=sep, skiprows=[], parse_dates=True)
    graph(data)
