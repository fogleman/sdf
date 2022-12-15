"""
Copyright 2010 Lars Kruse <devel@sumpfralle.de>

This file is part of PyCAM.

PyCAM is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PyCAM is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PyCAM.  If not, see <http://www.gnu.org/licenses/>.
"""

import logging
import time


def is_debug():
    log = get_logger()
    return log.level <= logging.DEBUG


def get_logger(suffix=None):
    name = "PyCAM"
    if suffix:
        name += ".%s" % str(suffix)
    logger = logging.getLogger(name)
    if len(logger.handlers) == 0:
        init_logger(logger)
    return logger


def init_logger(log, logfilename=None):
    if logfilename:
        datetime_format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        logfile_handler = logging.FileHandler(logfilename)
        logfile_handler.setFormatter(datetime_format)
        logfile_handler.addFilter(RepetitionsFilter(logfile_handler, log))
        log.addHandler(logfile_handler)
    console_output = logging.StreamHandler()
    console_output.addFilter(RepetitionsFilter(console_output, log))
    log.addHandler(console_output)
    log.setLevel(logging.INFO)
    log.debug2 = lambda *args, **kwargs: log.log(logging.DEBUG - 1, *args, **kwargs)
    # store the latest log items in a queue (for pushing them into new handlers)
    buffer_handler = BufferHandler()
    buffer_handler.addFilter(RepetitionsFilter(buffer_handler, log))
    log.addHandler(buffer_handler)


def _push_back_old_logs(new_handler):
    log = get_logger()
    # push all older log items into the new handler
    for handler in log.handlers:
        if hasattr(handler, "push_back"):
            handler.push_back(new_handler)


def add_stream(stream, level=None):
    log = get_logger()
    logstream = logging.StreamHandler(stream)
    if level is not None:
        logstream.setLevel(level)
    logstream.addFilter(RepetitionsFilter(logstream, log))
    log.addHandler(logstream)
    _push_back_old_logs(logstream)


def add_hook(callback, level=None):
    log = get_logger()
    loghook = HookHandler(callback)
    if level is not None:
        loghook.setLevel(level)
    loghook.addFilter(RepetitionsFilter(loghook, log))
    log.addHandler(loghook)
    _push_back_old_logs(loghook)


def add_gtk_gui(parent_window, level=None):
    log = get_logger()
    loggui = GTKHandler(parent_window)
    if level is not None:
        loggui.setLevel(level)
    loggui.addFilter(RepetitionsFilter(loggui, log))
    log.addHandler(loggui)
    _push_back_old_logs(loggui)


class RepetitionsFilter(logging.Filter):

    def __init__(self, handler, logger, **kwargs):
        logging.Filter.__init__(self, **kwargs)
        self._logger = logger
        self._last_timestamp = 0
        self._last_record = None
        # Every handler needs its own "filter" instance - this is not really
        # a clean style.
        self._handler = handler
        self._suppressed_messages_counter = 0
        self._cmp_len = 30
        self._delay = 3

    def filter(self, record):
        now = time.time()
        if self._logger.getEffectiveLevel() <= logging.DEBUG:
            # skip only identical lines in debug mode
            message_equal = (self._last_record
                             and (record.getMessage() == self._last_record.getMessage()))
            similarity = "identical"
        else:
            # skip similar lines in non-debug modes
            message_equal = self._last_record and record.getMessage().startswith(
                self._last_record.getMessage()[:self._cmp_len])
            similarity = "similar"
        if not is_debug() and (message_equal and (now - self._last_timestamp <= self._delay)):
            self._suppressed_messages_counter += 1
            return False
        else:
            if self._suppressed_messages_counter > 0:
                # inject a message regarding the previously suppressed messages
                self._last_record.msg = "*** skipped %d %s message(s) ***"
                self._last_record.args = (self._suppressed_messages_counter, similarity)
                self._handler.emit(self._last_record)
            self._last_record = record
            self._last_timestamp = now
            self._suppressed_messages_counter = 0
            return True


class BufferHandler(logging.Handler):

    MAX_LENGTH = 100

    def __init__(self, **kwargs):
        logging.Handler.__init__(self, **kwargs)
        self.record_buffer = []

    def emit(self, record):
        self.record_buffer.append(record)
        # reduce the record_buffer queue if necessary
        while len(self.record_buffer) > self.MAX_LENGTH:
            self.record_buffer.pop(0)

    def push_back(self, other_handler):
        for record in self.record_buffer:
            if record.levelno >= other_handler.level:
                other_handler.emit(record)


class GTKHandler(logging.Handler):

    def __init__(self, parent_window=None, **kwargs):
        logging.Handler.__init__(self, **kwargs)
        self.parent_window = parent_window

    def emit(self, record):
        message = self.format(record)
        # Replace all "<>" characters (invalid for markup styles) with html entities.
        message = message.replace("<", "&lt;").replace(">", "&gt;")
        from gi.repository import Gtk
        if record.levelno <= 20:
            message_type = Gtk.MessageType.INFO
            message_title = "Information"
        elif record.levelno <= 30:
            message_type = Gtk.MessageType.WARNING
            message_title = "Warning"
        else:
            message_type = Gtk.MessageType.ERROR
            message_title = "Error"
        window = Gtk.MessageDialog(self.parent_window, type=message_type,
                                   buttons=Gtk.ButtonsType.OK)
        window.set_markup(str(message))
        window.set_title(message_title)
        # make sure that the window gets destroyed later
        for signal in ("close", "response"):
            window.connect(signal, lambda dialog, *args: dialog.destroy())
        # accept "destroy" action -> remove window
        window.connect("destroy", lambda *args: True)
        # show the window, but don't wait for a response
        window.show()


class HookHandler(logging.Handler):

    def __init__(self, callback, **kwargs):
        logging.Handler.__init__(self, **kwargs)
        self.callback = callback

    def emit(self, record):
        message = self.format(record)
        message_type = record.levelname
        self.callback(message_type, message, record=record)
