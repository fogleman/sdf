from pycam.Utils.events import get_event_handler, get_mainloop


class ProgressContext:

    def __init__(self, title):
        self._title = title
        self._progress = get_event_handler().get("progress")

    def __enter__(self):
        if self._progress:
            self._progress.update(text=self._title, percent=0)
            # start an indefinite pulse (until we receive more details)
            self._progress.update()
        else:
            self._progress = None
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        if self._progress:
            self._progress.finish()

    def update(self, *args, **kwargs):
        mainloop = get_mainloop()
        if mainloop is None:
            return False
        mainloop.update()
        if self._progress:
            return self._progress.update(*args, **kwargs)
        else:
            return False

    def set_multiple(self, count, base_text=None):
        if self._progress:
            self._progress.set_multiple(count, base_text=base_text)

    def update_multiple(self):
        if self._progress:
            self._progress.update_multiple()
