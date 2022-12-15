import collections
import contextlib
import datetime
import io

from pycam.errors import PycamBaseException
from pycam.Flow.parser import dump_yaml, parse_yaml
from pycam.Utils.events import get_event_handler
import pycam.Utils.log

_log = pycam.Utils.log.get_logger()


class DataRevision:
    """ create a representation of the current state of all collections """

    def __init__(self):
        """ create a representation of the current state of all collections """
        self.timestamp = datetime.datetime.now()
        self.dump = dump_yaml()

    def __lt__(self, other):
        """sort revisions by timestamp"""
        return (self.timestamp, self.dump) < (other.timestamp, other.dump)


class DataHistory:
    """ manage the revisions of the data collections """

    max_revision_count = 20
    subscribed_events = {"model-changed", "model-list-changed",
                         "tool-changed", "tool-list-changed",
                         "process-changed", "process-list-changed",
                         "bounds-changed", "bounds-list-changed",
                         "task-changed", "task-list-changed",
                         "toolpath-changed", "toolpath-list-changed"}

    def __init__(self):
        self._revisions = collections.deque([], self.max_revision_count)
        self._register_events()
        # count "ignore change" requests (greater than zero -> ignore changes)
        self._ignore_change_depth = 0
        self._skipped_revision_store_count = 0
        self._store_revision()

    def __del__(self):
        self.cleanup()

    def cleanup(self):
        self._unregister_events()

    def clear(self):
        if self._revisions:
            self._revisions.clear()
            get_event_handler().emit_event("history-changed")

    @contextlib.contextmanager
    def merge_changes(self, no_store=False):
        """ postpone storing individual revisions until the end of the context

        Use this context if you want to force-merge multiple changes (e.g. load/restore) into a
        single revision.
        """
        previous_count = self._skipped_revision_store_count
        self._ignore_change_depth += 1
        try:
            yield
        finally:
            self._ignore_change_depth -= 1
        # store a new revision if a change occurred in between
        if not no_store and (previous_count != self._skipped_revision_store_count):
            self._store_revision()

    def get_undo_steps_count(self):
        return len(self._revisions)

    def restore_previous_state(self):
        if len(self._revisions) > 1:
            self._revisions.pop()
            event_handler = get_event_handler()
            # we do not expect a "change" since we switch to a previous state
            with self.merge_changes(no_store=True):
                with event_handler.blocked_events(self.subscribed_events, emit_after=True):
                    source = io.StringIO(self._revisions[-1].dump)
                    parse_yaml(source, reset=True)
            _log.info("Restored previous state from history (%d/%d)",
                      len(self._revisions) + 1, self.max_revision_count)
            event_handler.emit_event("history-changed")
            return True
        else:
            _log.warning("Failed to restore previous state from history: no more states left")
            return False

    def _register_events(self):
        event_handler = get_event_handler()
        for event in self.subscribed_events:
            event_handler.register_event(event, self._store_revision)

    def _unregister_events(self):
        event_handler = get_event_handler()
        while self.subscribed_events:
            event = self.subscribed_events.pop()
            event_handler.unregister_event(event, self._store_revision)

    def _store_revision(self):
        if self._ignore_change_depth > 0:
            self._skipped_revision_store_count += 1
        else:
            _log.info("Storing a state revision (%d/%d)",
                      len(self._revisions) + 1, self.max_revision_count)
            self._revisions.append(DataRevision())
            get_event_handler().emit_event("history-changed")


@contextlib.contextmanager
def merge_history_and_block_events(settings, emit_events_after=True):
    """merge all history changes to a single one and block all events (emitting them later)"""
    history = settings.get("history")
    if history:
        with history.merge_changes():
            with settings.blocked_events(history.subscribed_events, emit_after=emit_events_after):
                yield
    else:
        yield


@contextlib.contextmanager
def rollback_history_on_failure(settings):
    history = settings.get("history")
    if history:
        start_count = history.get_undo_steps_count()
        try:
            yield
        except PycamBaseException as exc:
            _log.warning("Reverting changes due a failure: %s", exc)
            if start_count != history.get_undo_steps_count():
                history.restore_previous_state()
