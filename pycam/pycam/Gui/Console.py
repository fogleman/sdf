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

import os


class ConsoleProgressBar:

    STYLE_NONE = 0
    STYLE_TEXT = 1
    STYLE_BAR = 2
    STYLE_DOT = 3
    PROGRESS_BAR_LENGTH = 70

    def __init__(self, output, style=None):
        if style is None:
            style = ConsoleProgressBar.STYLE_TEXT
        self.output = output
        self.style = style
        self.last_length = 0
        self.text = ""
        self.percent = 0

    def _output_current_state(self, progress_happened=True):
        if self.style == ConsoleProgressBar.STYLE_TEXT:
            text = "%d%% %s" % (self.percent, self.text)
            self.last_length = len(text)
        elif self.style == ConsoleProgressBar.STYLE_BAR:
            bar_length = ConsoleProgressBar.PROGRESS_BAR_LENGTH
            hashes = int(bar_length * self.percent / 100.0)
            empty = bar_length - hashes
            text = "[%s%s]" % ("#" * hashes, "." * empty)
            # include a text like " 10% " in the middle
            percent_text = " %d%% " % self.percent
            start_text = text[:(len(text) - len(percent_text)) / 2]
            end_text = text[-(len(text) - len(start_text) - len(percent_text)):]
            text = start_text + percent_text + end_text
            self.last_length = len(text)
        elif self.style == ConsoleProgressBar.STYLE_DOT:
            if progress_happened:
                text = "."
            else:
                text = ""
            # don't remove any previous characters
            self.last_length = 0
        else:
            raise ValueError("ConsoleProgressBar: invalid style (%d)" % self.style)
        self.output.write(text)
        self.output.flush()

    def update(self, text=None, percent=None, **kwargs):
        if self.style == ConsoleProgressBar.STYLE_NONE:
            return
        if text is not None:
            self.text = text
        if percent is not None:
            self.percent = int(percent)
        if self.last_length > 0:
            # delete the previous line
            self.output.write("\x08" * self.last_length)
        self._output_current_state(progress_happened=(percent is not None))

    def finish(self):
        if self.style == ConsoleProgressBar.STYLE_NONE:
            return
        # show that we are finished
        self.update(percent=100)
        # finish the line
        self.output.write(os.linesep)
