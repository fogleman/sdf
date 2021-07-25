import collections
import contextlib

import pycam.Gui.Settings
import pycam.Utils.log


log = pycam.Utils.log.get_logger()


UISection = collections.namedtuple("UISection", ("add_func", "clear_func", "widgets"))
UIWidget = collections.namedtuple("UIWidget", ("name", "obj", "weight", "args"))
UIEvent = collections.namedtuple("UIEvent", ("handlers", "blocker_tokens", "statistics"))
UIChain = collections.namedtuple("UIChain", ("func", "weight"))


__event_handlers = []
__mainloop = []


def get_mainloop(use_gtk=False):
    """create new or return an existing mainloop

    @param use_gtk: supply Gtk with timeslots for event handling (active if this parameter is True
        at least once)
    """
    try:
        mainloop = __mainloop[0]
    except IndexError:
        try:
            mainloop = GtkMainLoop()
        except ImportError:
            log.warning("No event loop is available")
            mainloop = None
        __mainloop.append(mainloop)
    return mainloop


class GtkMainLoop:

    def __init__(self):
        import gi
        gi.require_version("Gtk", "3.0")
        from gi.repository import Gtk
        self._gtk = Gtk
        self._is_running = False

    def run(self):
        if self._is_running:
            log.warning("Refusing to run main loop again, while we are running")
            return
        self._is_running = True
        try:
            self._gtk.main()
        except KeyboardInterrupt:
            pass
        self._is_running = False

    def stop(self):
        if self._is_running:
            log.debug("Stopping main loop")
            self._gtk.main_quit()
        else:
            log.info("Main loop was stopped before")

    def update(self):
        while self._gtk.events_pending():
            self._gtk.main_iteration()


def get_event_handler():
    if not __event_handlers:
        __event_handlers.append(EventCore())
    return __event_handlers[0]


class EventCore(pycam.Gui.Settings.Settings):

    def __init__(self):
        super().__init__()
        self.event_handlers = {}
        self.ui_sections = {}
        self.chains = {}
        self.state_dumps = []
        self.namespace = {}

    def register_event(self, event, target):
        assert callable(target) or isinstance(target, str)
        if event not in self.event_handlers:
            self.event_handlers[event] = UIEvent([], [],
                                                 {"emitted": 0, "blocked": 0, "handled": 0})
        self.event_handlers[event].handlers.append(target)

    def unregister_event(self, event, target):
        if event in self.event_handlers:
            removal_list = []
            handlers = self.event_handlers[event]
            for index, item in enumerate(handlers.handlers):
                if target == item:
                    removal_list.append(index)
            removal_list.reverse()
            for index in removal_list:
                handlers.handlers.pop(index)
        else:
            log.info("Trying to unregister an unknown event: %s", event)

    def get_events_summary(self):
        return {key: {"handlers": tuple(handler for handler in event.handlers),
                      "emitted": event.statistics["emitted"],
                      "handled": event.statistics["handled"],
                      "blocked": event.statistics["blocked"]}
                for key, event in self.event_handlers.items()}

    def get_events_summary_lines(self):
        return ["{} ({:d}, {:d}/{:d})".format(event, len(stats["handlers"]), stats["handled"],
                                              stats["emitted"])
                for event, stats in sorted(self.get_events_summary().items())]

    def emit_event(self, event):
        log.debug2("Event emitted: %s", event)
        if event in self.event_handlers:
            self.event_handlers[event].statistics["emitted"] += 1
            if self.event_handlers[event].blocker_tokens:
                self.event_handlers[event].statistics["blocked"] += 1
                log.debug2("Ignoring blocked event: %s", event)
            else:
                # prevent infinite recursion
                with self.blocked_events({event}, disable_log=True):
                    self.event_handlers[event].statistics["handled"] += 1
                    for handler in self.event_handlers[event].handlers:
                        log.debug2("Calling event handler: %s", handler)
                        if isinstance(handler, str):
                            # event names are acceptable
                            self.emit_event(handler)
                        else:
                            handler()
        else:
            log.debug("No events registered for event '%s'", event)

    def block_event(self, event, disable_log=False):
        if event in self.event_handlers:
            self.event_handlers[event].blocker_tokens.append(True)
            if not disable_log:
                log.debug2("Blocking an event: %s (%d blockers reached)",
                           event, len(self.event_handlers[event].blocker_tokens))
        else:
            if not disable_log:
                log.info("Trying to block an unknown event: %s", event)

    def unblock_event(self, event, disable_log=False):
        if event in self.event_handlers:
            if self.event_handlers[event].blocker_tokens:
                self.event_handlers[event].blocker_tokens.pop()
                if not disable_log:
                    log.debug2("Unblocking an event: %s (%d blockers remaining)",
                               event, len(self.event_handlers[event].blocker_tokens))
            else:
                if not disable_log:
                    log.debug("Trying to unblock non-blocked event '%s'", event)
        else:
            # "disable_log" is only relevant for the debugging messages above
            log.info("Trying to unblock an unknown event: %s", event)

    @contextlib.contextmanager
    def blocked_events(self, events, emit_after=False, disable_log=False):
        """ temporarily block a number of events for the duration of this context

        @param events: iterable of events to be blocked temporarily
        @param emit_after: emit all given events at the end of the context
        """
        unblock_list = []
        for event in events:
            self.block_event(event, disable_log=disable_log)
            unblock_list.append(event)
        unblock_list.reverse()
        try:
            yield
        finally:
            for event in unblock_list:
                self.unblock_event(event, disable_log=disable_log)
        if emit_after:
            for event in unblock_list:
                self.emit_event(event)

    def register_ui_section(self, section, add_action, clear_action):
        if section not in self.ui_sections:
            self.ui_sections[section] = UISection(None, None, [])
        else:
            log.error("Trying to register a ui section twice: %s", section)
        self.ui_sections[section] = UISection(add_action, clear_action,
                                              self.ui_sections[section].widgets)
        self._rebuild_ui_section(section)

    def unregister_ui_section(self, section):
        if section in self.ui_sections:
            ui_section = self.ui_sections[section]
            while ui_section.widgets:
                ui_section.widgets.pop()
            del self.ui_sections[section]
        else:
            log.info("Trying to unregister a non-existent ui section: %s", section)

    def clear_ui_section(self, section):
        ui_section = self.ui_sections[section]
        while ui_section.widgets:
            ui_section.widgets.pop()

    def _rebuild_ui_section(self, section):
        if section in self.ui_sections:
            ui_section = self.ui_sections[section]
            if ui_section.add_func or ui_section.clear_func:
                ui_section.widgets.sort(key=lambda x: x.weight)
                ui_section.clear_func()
                for item in ui_section.widgets:
                    ui_section.add_func(item.obj, item.name, **(item.args or {}))
        else:
            log.info("Failed to rebuild unknown ui section: %s", section)

    def register_ui(self, section, name, widget, weight=0, args_dict=None):
        if section not in self.ui_sections:
            log.info("Tried to register widget for non-existing UI: %s -> %s", name, section)
            self.ui_sections[section] = UISection(None, None, [])
        current_widgets = [item.obj for item in self.ui_sections[section].widgets]
        if (widget is not None) and (widget in current_widgets):
            log.info("Tried to register widget twice: %s -> %s", section, name)
            return
        self.ui_sections[section].widgets.append(UIWidget(name, widget, weight, args_dict))
        self._rebuild_ui_section(section)

    def unregister_ui(self, section, widget):
        if (section in self.ui_sections) or (None in self.ui_sections):
            if section not in self.ui_sections:
                section = None
            ui_section = self.ui_sections[section]
            removal_list = []
            for index, item in enumerate(ui_section.widgets):
                if item.obj == widget:
                    removal_list.append(index)
            removal_list.reverse()
            for index in removal_list:
                ui_section.widgets.pop(index)
            self._rebuild_ui_section(section)
        else:
            log.info("Trying to unregister unknown ui section: %s", section)

    def register_chain(self, name, func, weight=100):
        if name not in self.chains:
            self.chains[name] = []
        self.chains[name].append(UIChain(func, weight))
        self.chains[name].sort(key=lambda item: item.weight)

    def unregister_chain(self, name, func):
        if name in self.chains:
            for index, data in enumerate(self.chains[name]):
                if data.func == func:
                    self.chains[name].pop(index)
                    break
            else:
                log.info("Trying to unregister unknown function from %s: %s", name, func)
        else:
            log.info("Trying to unregister from unknown chain: %s", name)

    def call_chain(self, name, *args, **kwargs):
        if name in self.chains:
            for data in self.chains[name]:
                data.func(*args, **kwargs)
        else:
            # this may happen during startup
            log.debug("Called an unknown chain: %s", name)

    def reset_state(self):
        pass

    def register_namespace(self, name, value):
        if name in self.namespace:
            log.info("Trying to register the same key in namespace twice: %s", name)
        self.namespace[name] = value

    def unregister_namespace(self, name):
        if name not in self.namespace:
            log.info("Tried to unregister an unknown name from namespace: %s", name)

    def get_namespace(self):
        return self.namespace
