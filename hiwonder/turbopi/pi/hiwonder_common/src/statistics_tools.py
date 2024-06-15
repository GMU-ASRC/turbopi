from . import pid

# from typing import override


def fmap(x, in_min, in_max, out_min, out_max):
    """
    Given a set of ranges, remap x to a new set of ranges.

    Converted to Python from Arduino's Map() function.
    """
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min


def imap(x, in_min, in_max, out_min, out_max) -> int:
    """Given a set of ranges, remap x to a new set of ranges."""
    return int(fmap(in_min, in_max, out_min, out_max))


def constrain(x, in_min, in_max):
    """Constrain input value between in_min and in_max."""
    return min(in_max, max(in_min, x))


def mean(m) -> float:  # polyfill because Micropython has no module 'statistics'
    return sum(m) / len(m)


class Deadzone():
    """
    Return center value if in deadzone radius (inclusive)

    Can also constrain value to be between min_out and max_out
    """

    def __init__(self, radius, center=0, min_out=None, max_out=None):
        self.r = radius
        self.min = min_out
        self.max = max_out
        self.center = center
        if (self.min is not None and radius < self.min
                or self.max is not None and radius > self.max):
            raise ValueError("center is outside of min/max range")

    @property
    def d(self):
        return self.r * 2

    def __call__(self, x):
        if self.center - self.r <= x <= self.center + self.r:
            x = self.center
        if self.min is not None and x < self.min:
            x = self.min
        if self.max is not None and x > self.max:
            x = self.max
        return x

    def __contains__(self, x):
        return True if self.__call__(x) == self.center else False


class Average():
    """
    FIFO moving average.

    When an instance is called with an argument, it will add the argument to
    a list and return the average of the list. Useful for rolling averages.

    The returned average can optionally collapse into a boolean value based on
    a user-set threshold. Use the returned average in a bool context to do this.

    Examples:
    averager = Average(3)
    bool(averager([True, True]))  # avg of True,  True returns True
    bool(averager(False))  # avg of True,  True, False returns True
    bool(averager(False))  # avg of True, False, False returns False
    averager.list = [30, 0]
    averager(0)  # avg of 30, 0, 0 returns 5.0
    averager(0)  # avg of  0, 0, 0 returns 0.0
    """

    def __init__(self, max_len=None, threshold=0.5):
        if max_len is not None and max_len < 0:
            raise ValueError
        self.n = max_len
        self._list = []
        self.threshold = threshold

    def __call__(self, *args):
        for value in args:
            self._append(value)
        return self.avg

    def __len__(self):
        return len(self.list)

    def _append(self, item):
        try:
            self.list = self.list + list(item)  # for if item is a list
        except TypeError:
            self.list.append(item)

    def append(self, item):
        self.list.append(item)
        return self

    @property
    def list(self):
        if self.n is not None and len(self._list) > self.n:
            self._list = self._list[len(self._list) - self.n:]
        return self._list

    @list.setter
    def list(self, rvalue):
        self._list = rvalue

    @property
    def avg(self):
        return FloatingBool(mean(self.list), self.threshold)


class FIRFilter(Average):
    def __init__(self, filter, threshold=0.5, fill=0):
        super().__init__(len(filter), threshold)
        self.filter = filter
        self.list = [fill for i in range(len(filter))]

    def __call__(self, *args):
        for value in args:
            self._append(value)
        return self.out

    @property
    def out(self):
        return FloatingBool(sum([self.list[i] * self.filter[i] for i in range(len(self.filter))]),
                            self.threshold)


class FloatingBool(float):
    """float that can collapse into a boolean value based on activation"""
    def __new__(cls, *args, **kwargs):
        return float.__new__(cls, args[0])

    def __init__(self, f, threshold=None):
        float.__init__(f)
        self.f = float(f)
        self.threshold = threshold

    def __bool__(self):
        if self.threshold is None:
            return bool(self)
        else:
            return True if self > self.threshold else False

    def __int__(self):
        return int(self.f)


class AverageCustom(Average):
    """
    Fifo averager that allows usage of custom accessor function.

    Does not support custom boolean collapsation.

    Example:
    lambdas = (lambda item: item['x'], lambda item: item['y'])
    averager = AverageCustom(lambdas, 2)
    averager({'x':  0,  'y': 0})  # returns (0.0, 0.0)
    averager({'x': 10, 'y': 10})  # returns (5.0, 5.0)
    """

    def __init__(self, accessors, max_len=None):
        super().__init__(max_len)
        self.accessors = accessors

    @property
    def avg(self):
        averages = []
        for accessor in self.accessors:
            averages.append(mean(list(map(accessor, self.list))))
        return tuple(averages)


class PID(pid.PID):
    def __call__(self, error, scaler=1):
        return super().get_pid(error, scaler)


# returns list as cumulative, starting at element s onwards
# [1 1 1 1] becomes [1 2 3 4] where s = 1
def abs_fwd_timegraph(list_, s):
    y = list_.copy()
    for i in range(s, len(y)):
        y[i] += y[i - 1]
    return y


# calculates the slope of a linear regression of past n pairs
# based on https://stackoverflow.com/a/19040841/2712730
def linreg_past(x, y, n, compute_correlation=False):
    sumx = sum(x[-n:])
    sumx2 = sum([i**2 for i in x[-n:]])
    sumy = sum(y[-n:])
    sumy2 = sum([i**2 for i in y[-n:]])
    sumxy = sum([i * j for i, j in zip(x[-n:], y[-n:])])
    denom = n * sumx2 - sumx**2

    m = (n * sumxy - sumx * sumy) / denom
    b = (sumy * sumx2 - sumx * sumxy) / denom

    if compute_correlation:
        r = (
            (sumxy - sumx * sumy / n)
            / ((sumx2 - sumx**2)**0.5 / n)
            * (sumy2 - sumy**2 / n)
        )
    else:
        r = None
    return (m, b, r)


def get_average_value(
    avg_list: list,
    input: float = None,
    index: list = None
) -> float:
    if (input is not None and index is not None):
        avg_list[index[0]] = float(input)

    if (index is not None):
        index[0] = (index[0] + 1) % len(avg_list)

    output: float = 0.0
    for val in avg_list:
        if (val is None):
            return 0.0
        output += float(val)

    output /= float(len(avg_list))
    return float(output)
