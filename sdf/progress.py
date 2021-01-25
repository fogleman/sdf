import sys
import time

def pretty_time(seconds):
    seconds = int(round(seconds))
    s = seconds % 60
    m = (seconds // 60) % 60
    h = (seconds // 3600)
    return '%d:%02d:%02d' % (h, m, s)

class Bar(object):

    def __init__(self, max_value=100, min_value=0, enabled=True):
        self.min_value = min_value
        self.max_value = max_value
        self.value = min_value
        self.start_time = time.time()
        self.enabled = enabled

    @property
    def percent_complete(self):
        t = (self.value - self.min_value) / (self.max_value - self.min_value)
        return t * 100

    @property
    def elapsed_time(self):
        return time.time() - self.start_time

    @property
    def eta(self):
        t = self.percent_complete / 100
        if t == 0:
            return 0
        return (1 - t) * self.elapsed_time / t

    def increment(self, delta):
        self.update(self.value + delta)

    def update(self, value):
        self.value = value
        if self.enabled:
            sys.stdout.write('  %s    \r' % self.render())
            sys.stdout.flush()

    def done(self):
        self.update(self.max_value)
        self.stop()

    def stop(self):
        if self.enabled:
            sys.stdout.write('\n')
            sys.stdout.flush()

    def render(self):
        items = [
            self.render_percent_complete(),
            self.render_value(),
            self.render_bar(),
            self.render_elapsed_time(),
            self.render_eta(),
        ]
        return ' '.join(items)

    def render_percent_complete(self):
        return '%3.0f%%' % self.percent_complete

    def render_value(self):
        if self.min_value == 0:
            return '(%g of %g)' % (self.value, self.max_value)
        else:
            return '(%g)' % (self.value)

    def render_bar(self, size=30):
        a = int(round(self.percent_complete / 100.0 * size))
        b = size - a
        return '[' + '#' * a + '-'  * b + ']'

    def render_elapsed_time(self):
        return pretty_time(self.elapsed_time)

    def render_eta(self):
        return pretty_time(self.eta)
