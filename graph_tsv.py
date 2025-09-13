"""Graphs the input and output values of TurboPi robot(s) over time.

This script takes as arguments a list of paths, each of which can be:
* A single ``.tsv`` file
* A single ``.zip`` file containing a single ``io.tsv`` file
* A project folder containing an ``io.tsv`` file
* A folder containing multiple ``.zip`` files or project folders, each containing ``io.tsv`` files

.. note::
    If a folder containing a ``.zip`` file is specified, the script will ignore
    any other files or directories in the folder.


You can also trim the time range of the graph by specifying the start and end times as arguments:
``--offset <seconds>``: Skips the specified number of seconds from the start of each log.
``--offset_end <seconds>``: Skips the specified number of seconds from before the end of each log.
``--length <seconds>``: Constrains the length of the graph to the specified number of seconds.
"""

import sys
import zipfile
import argparse
import tempfile
import colorsys
import itertools
import pathlib as pl
from ast import literal_eval as eval

import pandas as pd
from matplotlib import pyplot as plt

try:
    # if hiwonder_common is installed, use it
    from hiwonder_common import project
    import hiwonder_common.graph_tsv as g
except ImportError:
    # otherwise, use path hack to import the local version
    import sys
    cwd = pl.Path(__file__).resolve().parent
    path = cwd / "pi/hiwonder_common/src"
    sys.path.append(str(path.resolve()))
    import hiwonder_common.project as project
    import hiwonder_common.graph_tsv as g


def hr(h, s, l):  # noqa: E741
    return colorsys.hls_to_rgb(h, l, s)


cr = hr(0.0, 0.9, 0.4)
cb = hr(0.6, 0.9, 0.4)
cg = hr(0.3, 0.9, 0.4)


def graph(data):
    # old graphing code
    plt.rcParams["figure.figsize"] = [7.00, 3.50]
    plt.rcParams["figure.autolayout"] = True
    # read the csv files using pandas excluding the timedate column
    # df = df.drop(columns=['time'], axis=1)

    _fig, ax = plt.subplots()
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
            xnot.append(ts.iloc[-1])

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


def _suplabels(self, t, info, **kwargs):
    import matplotlib as mpl

    suplab = getattr(self, info['name'], None)

    x = kwargs.pop('x', None)
    y = kwargs.pop('y', None)
    if info['name'] in ['_supxlabel', '_suptitle']:
        autopos = y is None
    elif info['name'] in ['_supylabel', '_supyrlabel']:
        autopos = x is None
    if x is None:
        x = info['x0']
    if y is None:
        y = info['y0']

    if 'horizontalalignment' not in kwargs and 'ha' not in kwargs:
        kwargs['horizontalalignment'] = info['ha']
    if 'verticalalignment' not in kwargs and 'va' not in kwargs:
        kwargs['verticalalignment'] = info['va']
    if 'rotation' not in kwargs:
        kwargs['rotation'] = info['rotation']

    if 'fontproperties' not in kwargs:
        if 'fontsize' not in kwargs and 'size' not in kwargs:
            kwargs['size'] = mpl.rcParams[info['size']]
        if 'fontweight' not in kwargs and 'weight' not in kwargs:
            kwargs['weight'] = mpl.rcParams[info['weight']]

    sup = self.text(x, y, t, **kwargs)
    if suplab is not None:
        suplab.set_text(t)
        suplab.set_position((x, y))
        suplab.update_from(sup)
        sup.remove()
    else:
        suplab = sup
    suplab._autopos = autopos
    setattr(self, info['name'], suplab)
    self.stale = True
    return suplab


def supyrlabel(self, t, **kwargs):
    # docstring from _suplabels...
    info = {'name': '_supyrlabel', 'x0': 0.98, 'y0': 0.5,
            'ha': 'right', 'va': 'center', 'rotation': 'vertical',
            'rotation_mode': 'anchor', 'size': 'figure.labelsize',
            'weight': 'figure.labelweight'}
    return _suplabels(self, t, info, **kwargs)


def graph_multiple(datas):
    plt.rcParams["figure.figsize"] = [7.00, 5.00]
    fig, axs = plt.subplots(len(datas))
    if len(datas) == 1:
        axs = [axs]


    plots = [g.plot_single(fig, ax, data) for ax, data in zip(axs, datas)]

    fig, ax, axw = plots[-1]

    # Labels and Title

    # make the legend
    # grab the artists from the last row
    handles, labels = ax.get_legend_handles_labels()
    a, b = axw.get_legend_handles_labels()
    handles.insert(-1, *a)
    labels.insert(-1, *b)

    show_title = True

    # show the legend
    if len(datas) == 1:
        legend = ax.legend(handles=handles, loc='lower center', ncol=3, fancybox=True, shadow=True)
    else:
        bbox = {'bbox_to_anchor': (0.5, 0.95)} if show_title else {}  # only shift the legend downwards if title shown
        legend = fig.legend(handles=handles, loc='upper center', ncol=3, fancybox=True, shadow=True,
                            **bbox)
    # set the linewidth of each legend object
    for obj in legend.legend_handles:
        obj.set_linewidth(3.0)
    s = legend.legend_handles[-1]  # the last column should be the vertical lines.
    s.set_linewidth(10.0)  # Draw that thicker in the legend
    s.set_alpha(0.25)

    if len(datas) == 1:
        if show_title:
            plt.title("Output Values over Time")
        ax.set_xlabel("Time since start (seconds)", loc='center')
        ax.set_ylabel("Forward Velocity (m/s)")
        axw.set_ylabel("Angular Velocity (rad/s)")
        fig.subplots_adjust(right=(1 - fig.subplotpars.left))
    else:
        if show_title:
            fig.suptitle("Output Values over Time")
        top = 0.87 if show_title else 0.88
        fig.supxlabel("Time since start (seconds)", ha='center')
        fig.supylabel("Forward Velocity (m/s)")
        supyrlabel(fig, "Angular Velocity (rad/s)")
        fig.subplots_adjust(top=top, hspace=0.08, right=(1 - fig.subplotpars.left), bottom=0.1)
    # plt.grid(True)
    return plt


tempdirs = []


def get_tsv_paths(filename):
    # There's different behavior depending on whether we're given a single file or a directory
    # single project zip file
    if filename.suffix == '.zip':
        # if the file is a zip file, extract it to a temporary directory
        tempdir = tempfile.TemporaryDirectory(prefix=filename.name)
        tempdirs.append(tempdir)
        with zipfile.ZipFile(filename) as d:
            d.extractall(tempdir.name)
        return [pl.Path(tempdir.name) / 'io.tsv']
    # single io.tsv file
    elif filename.is_file():
        return [filename]  # if file, assume it's a single data file
    # single project folder containing io.tsv file
    elif (f := g.make_project(filename).root / 'io.tsv').exists():
        return [f]

    # folder containing multiple projects
    def is_folder_or_zip(p):
        return p.is_dir() or p.suffix == '.zip'
    # filter down to only folders or zip files
    projects = [proj for proj in filename.iterdir() if is_folder_or_zip(proj)]
    if not projects:
        print(f"No projects found in folder:\n{filename:s}\nPlease specify a directory containing project folders.")
        sys.exit(1)
    # if any of the projects are zip files, assume we only care about .zip files and
    # extract them to a temporary directory with the same name as the folder originally containing them
    if any(p.suffix == '.zip' for p in projects):
        tempdir = tempfile.TemporaryDirectory(prefix=filename.name)
        tempdirs.append(tempdir)
        for p in projects:
            if p.suffix == '.zip':
                with zipfile.ZipFile(p) as d:
                    d.extractall(pl.Path(tempdir.name) / p.stem)
        # now that we've unzipped the projects, update the paths to the temp project folders
        projects = [pl.Path(tempdir.name) / p.stem for p in projects]
    # make a list of the io.tsv files in each project folder
    return [g.make_project(p).root / 'io.tsv' for p in projects]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("filename", help="csv file to be graphed", nargs='+')
    parser.add_argument("--offset", type=float, help="Number of seconds at the start of the file to skip", default=None)
    parser.add_argument("--offset_end", type=float, help="Number of seconds at the end of the file to ignore", default=None)
    parser.add_argument("--length", type=float, help="Length of time to graph in seconds", default=None)
    # parser.add_argument("--multiple", action='store_true', help="Plot multiple files")
    args = parser.parse_args()

    # get a list of paths to io.tsv files
    files = []
    for f in args.filename:
        files.extend(get_tsv_paths(pl.Path(f)))

    # make sure the files are not too large to graph
    if project and any(oversize := [project.inquire_size(f) for f in files]):
        print(f"{oversize[0]} is too large to graph.")
        sys.exit(1)

    # read the io.tsv files
    runs = []
    for data_file in files:
        try:
            runs.append(g.data_from_file(data_file, args.offset, args.offset_end, args.length))
        except ValueError as err:
            print(err)
            sys.exit(1)

    # if we unzipped anything, clean up the temp directories
    for tempdir in tempdirs:
        tempdir.cleanup()

    # plt.rcParams["figure.dpi"] = 600
    plt.rcParams["savefig.dpi"] = 600
    plt.rcParams["figure.figsize"] = [7.00, 5.00]

    plt = graph_multiple(runs)
    plt.show()
