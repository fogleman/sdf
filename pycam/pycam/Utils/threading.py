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

# multiprocessing is imported later
# import multiprocessing
import os
import platform
import queue
import random
import signal
import socket
import sys
import time
import uuid

from pycam.errors import CommunicationError
import pycam.Utils
import pycam.Utils.log
log = pycam.Utils.log.get_logger()


try:
    from multiprocessing.managers import SyncManager as _SyncManager
except ImportError as msg:
    log.debug("Failed to import multiprocessing.managers.SyncMananger: %s", msg)
else:
    # this class definition needs to be at the top level - for pyinstaller
    class TaskManager(_SyncManager):
        @classmethod
        def _run_server(cls, *args):
            # make sure that the server ignores SIGINT (KeyboardInterrupt)
            signal.signal(signal.SIGINT, signal.SIG_IGN)
            # prevent connection errors to trigger exceptions
            try:
                _SyncManager._run_server(*args)
            except socket.error:
                pass

DEFAULT_PORT = 1250


# TODO: create one or two classes for these functions (to get rid of the globals)

# possible values:
#   None: not initialized
#   False: no threading
#   multiprocessing: the multiprocessing module is imported and enabled later
__multiprocessing = None

# needs to be initialized, if multiprocessing is enabled
__num_of_processes = None

__manager = None
__closing = None
__task_source_uuid = None
__finished_jobs = []
__issued_warnings = []


def run_in_parallel(*args, **kwargs):
    global __manager
    if __manager is None:
        if pycam.Utils.log.is_debug():
            # force serial processing in debug mode
            kwargs = dict(kwargs)
            kwargs["disable_multiprocessing"] = True
        return run_in_parallel_local(*args, **kwargs)
    else:
        return run_in_parallel_remote(*args, **kwargs)


def is_pool_available():
    return __manager is not None


def is_multiprocessing_available():
    if (pycam.Utils.get_platform() == pycam.Utils.OSPlatform.WINDOWS) and \
            hasattr(sys, "frozen") and sys.frozen:
        return False
    try:
        import multiprocessing
        # try to initialize a semaphore - this can trigger shm access failures
        # (e.g. on Debian Lenny with Python 2.6.6)
        multiprocessing.Semaphore()
        return True
    except ImportError:
        if "missing_module" not in __issued_warnings:
            log.info("Python's multiprocessing module is missing: disabling parallel processing")
            __issued_warnings.append("missing_module")
    except OSError:
        if "shm_access_failed" not in __issued_warnings:
            log.info("Python's multiprocessing module failed to acquire read/write access to "
                     "shared memory (shm) - disabling parallel processing")
            __issued_warnings.append("shm_access_failed")
    return False


def is_multiprocessing_enabled():
    return bool(__multiprocessing)


def is_server_mode_available():
    # the following definition should be kept in sync with the documentation in
    # docs/parallel-processing.md
    return is_multiprocessing_available()


def get_number_of_processes():
    if __num_of_processes is None:
        return 1
    else:
        return __num_of_processes


def get_number_of_cores():
    try:
        import multiprocessing
        return multiprocessing.cpu_count()
    except ImportError:
        return None


def get_pool_statistics():
    global __manager
    if __manager is None:
        return []
    else:
        return __manager.statistics().get_worker_statistics()


def get_task_statistics():
    global __manager
    result = {}
    if __manager is not None:
        try:
            result["tasks"] = __manager.tasks().qsize()
            result["results"] = __manager.results().qsize()
        except NotImplementedError:
            # this can happen on MacOS (see multiprocessing doc)
            pass
        result["pending"] = __manager.pending_tasks().length()
        result["cache"] = __manager.cache().length()
    return result


class ManagerInfo:
    """ this separate class allows proper pickling for "multiprocesssing"
    """

    def __init__(self, tasks, results, stats, cache, pending):
        self.tasks_queue = tasks
        self.results_queue = results
        self.statistics = stats
        self.cache = cache
        self.pending_tasks = pending

    def get_tasks_queue(self):
        return self.tasks_queue

    def get_results_queue(self):
        return self.results_queue

    def get_statistics(self):
        return self.statistics

    def get_cache(self):
        return self.cache

    def get_pending_tasks(self):
        return self.pending_tasks


def init_threading(number_of_processes=None, enable_server=False, remote=None, run_server=False,
                   server_credentials="", local_port=DEFAULT_PORT):
    global __multiprocessing, __num_of_processes, __manager, __closing, __task_source_uuid
    if __multiprocessing:
        # kill the manager and clean everything up for a re-initialization
        cleanup()
    if (not is_server_mode_available()) and (enable_server or run_server):
        # server mode is disabled for the Windows pyinstaller standalone
        # due to "pickle errors". How to reproduce: run the standalone binary
        # with "--enable-server --server-auth-key foo".
        feature_matrix_text = ("Take a look at the wiki for a matrix of platforms and available "
                               "features: http://pycam.sourceforge.net/parallel-processing")
        if enable_server:
            log.warn("Unable to enable server mode with your current setup.\n%s",
                     feature_matrix_text)
        elif run_server:
            log.warn("Unable to run in server-only mode with the Windows standalone "
                     "executable.\n%s", feature_matrix_text)
        else:
            # no further warnings required
            pass
        enable_server = False
        run_server = False
    # only local -> no server settings allowed
    if (not enable_server) and (not run_server):
        remote = None
        run_server = None
        server_credentials = ""
    if not is_multiprocessing_available():
        __multiprocessing = False
        # Maybe a multiprocessing feature was explicitly requested?
        # Issue some warnings if necessary.
        multiprocessing_missing_text = (
            "Failed to enable server mode due to a lack of 'multiprocessing' capabilities. Please "
            "use Python2.6 or install the 'python-multiprocessing' package.")
        if enable_server:
            log.warn("Failed to enable server mode due to a lack of 'multiprocessing' "
                     "capabilities. %s", multiprocessing_missing_text)
        elif run_server:
            log.warn("Failed to run in server-only mode due to a lack of 'multiprocessing' "
                     "capabilities. %s", multiprocessing_missing_text)
        else:
            # no further warnings required
            pass
    else:
        import multiprocessing
        if number_of_processes is None:
            # use defaults
            # don't enable threading for a single cpu
            if (multiprocessing.cpu_count() > 1) or remote or run_server or enable_server:
                __multiprocessing = multiprocessing
                __num_of_processes = multiprocessing.cpu_count()
            else:
                __multiprocessing = False
        elif (number_of_processes < 1) and (remote is None) and (enable_server is None):
            # Zero processes are allowed if we use a remote server or offer a
            # server.
            __multiprocessing = False
        else:
            __multiprocessing = multiprocessing
            __num_of_processes = number_of_processes
    # initialize the manager
    if not __multiprocessing:
        __manager = None
        log.info("Disabled parallel processing")
    elif not enable_server and not run_server:
        __manager = None
        log.info("Enabled %d parallel local processes", __num_of_processes)
    else:
        # with multiprocessing
        log.info("Enabled %d parallel local processes", __num_of_processes)
        log.info("Allow remote processing")
        # initialize the uuid list for all workers
        worker_uuid_list = [str(uuid.uuid1()) for index in range(__num_of_processes)]
        __task_source_uuid = str(uuid.uuid1())
        if remote is None:
            # try to guess an appropriate interface for binding
            if pycam.Utils.get_platform() == pycam.Utils.OSPlatform.WINDOWS:
                # Windows does not support a wildcard interface listener
                all_ips = pycam.Utils.get_all_ips()
                if all_ips:
                    address = (all_ips[0], local_port)
                    log.info("Binding to local interface with IP %s", str(all_ips[0]))
                else:
                    raise CommunicationError("Failed to find any local IP")
            else:
                # empty hostname -> wildcard interface
                # (this does not work with Windows - see above)
                address = ('', local_port)
        else:
            if ":" in remote:
                host, port = remote.split(":", 1)
                try:
                    port = int(port)
                except ValueError:
                    log.warning("Invalid port specified: '%s' - using default port (%d) instead",
                                port, DEFAULT_PORT)
                    port = DEFAULT_PORT
            else:
                host = remote
                port = DEFAULT_PORT
            address = (host, port)
        if remote is None:
            tasks_queue = multiprocessing.Queue()
            results_queue = multiprocessing.Queue()
            statistics = ProcessStatistics()
            cache = ProcessDataCache()
            pending_tasks = PendingTasks()
            info = ManagerInfo(tasks_queue, results_queue, statistics, cache, pending_tasks)
            TaskManager.register("tasks", callable=info.get_tasks_queue)
            TaskManager.register("results", callable=info.get_results_queue)
            TaskManager.register("statistics", callable=info.get_statistics)
            TaskManager.register("cache", callable=info.get_cache)
            TaskManager.register("pending_tasks", callable=info.get_pending_tasks)
        else:
            TaskManager.register("tasks")
            TaskManager.register("results")
            TaskManager.register("statistics")
            TaskManager.register("cache")
            TaskManager.register("pending_tasks")
        __manager = TaskManager(address=address, authkey=server_credentials)
        # run the local server, connect to a remote one or begin serving
        try:
            if remote is None:
                __manager.start()
                log.info("Started a local server.")
            else:
                __manager.connect()
                log.info("Connected to a remote task server.")
        except (multiprocessing.AuthenticationError, socket.error) as err_msg:
            __manager = None
            return err_msg
        except EOFError:
            __manager = None
            raise CommunicationError("Failed to bind to socket for unknown reasons")
        # create the spawning process
        __closing = __manager.Value("b", False)
        if __num_of_processes > 0:
            # only start the spawner, if we want to use local workers
            spawner = __multiprocessing.Process(name="spawn", target=_spawn_daemon,
                                                args=(__manager, __num_of_processes,
                                                      worker_uuid_list))
            spawner.start()
        else:
            spawner = None
        # wait forever - in case of a server
        if run_server:
            log.info("Running a local server and waiting for remote connections.")
            # the server can be stopped via CTRL-C - it is caught later
            if spawner is not None:
                spawner.join()


def cleanup():
    global __multiprocessing, __manager, __closing
    if __multiprocessing and __closing:
        log.debug("Shutting down process handler")
        try:
            __closing.set(True)
        except (IOError, EOFError):
            log.debug("Connection to manager lost during cleanup")
        # Only managers that were started via ".start()" implement a "shutdown".
        # Managers started via ".connect" may skip this.
        if hasattr(__manager, "shutdown"):
            # wait for the spawner and the worker threads to go down
            time.sleep(2.5)
            # __manager.shutdown()
            time.sleep(0.1)
            # check if it is still alive and kill it if necessary
            if __manager._process.is_alive():
                __manager._process.terminate()
    __manager = None
    __closing = None
    __multiprocessing = None


def _spawn_daemon(manager, number_of_processes, worker_uuid_list):
    """ wait for items in the 'tasks' queue to appear and then spawn workers
    """
    global __multiprocessing, __closing
    tasks = manager.tasks()
    results = manager.results()
    stats = manager.statistics()
    cache = manager.cache()
    pending_tasks = manager.pending_tasks()
    log.debug("Spawner daemon started with %d processes", number_of_processes)
    log.debug("Registering %d worker threads: %s", len(worker_uuid_list), worker_uuid_list)
    last_cache_update = time.time()
    # use only the hostname (for brevity) - no domain part
    hostname = platform.node().split(".", 1)[0]
    try:
        while not __closing.get():
            # check the expire timeout of the cache from time to time
            if last_cache_update + 30 < time.time():
                cache.expire_cache_items()
                last_cache_update = time.time()
            if not tasks.empty():
                workers = []
                for task_id in worker_uuid_list:
                    task_name = "%s-%s" % (hostname, task_id)
                    worker = __multiprocessing.Process(name=task_name, target=_handle_tasks,
                                                       args=(tasks, results, stats, cache,
                                                             pending_tasks, __closing))
                    worker.start()
                    workers.append(worker)
                # wait until all workers are finished
                for worker in workers:
                    worker.join()
            else:
                time.sleep(1.0)
    except KeyboardInterrupt:
        log.info("Spawner daemon killed by keyboard interrupt")
        # set the "closing" flag and just exit
        try:
            __closing.set(True)
        except (IOError, EOFError):
            pass
    except (IOError, EOFError):
        # the connection was closed
        log.info("Spawner daemon lost connection to server")


def _handle_tasks(tasks, results, stats, cache, pending_tasks, closing):
    global __multiprocessing
    name = __multiprocessing.current_process().name
    local_cache = ProcessDataCache()
    timeout_limit = 60
    timeout_counter = 0
    last_worker_notification = 0
    log.debug("Worker thread started: %s" % name)
    try:
        while (timeout_counter < timeout_limit) and not closing.get():
            if last_worker_notification + 30 < time.time():
                stats.worker_notification(name)
                last_worker_notification = time.time()
            start_time = time.time()
            try:
                job_id, task_id, func, args = tasks.get(timeout=0.2)
            except queue.Empty:
                time.sleep(1.8)
                timeout_counter += 1
                continue
            # TODO: if the client aborts/disconnects between "tasks.get" and
            # "pending_tasks.add", the task is lost. We should better use some
            # backup.
            pending_tasks.add(job_id, task_id, (func, args))
            log.debug("Worker %s processes %s / %s", name, job_id, task_id)
            # reset the timeout counter, if we found another item in the queue
            timeout_counter = 0
            real_args = []
            for arg in args:
                if isinstance(arg, ProcessDataCacheItemID):
                    try:
                        value = local_cache.get(arg)
                    except KeyError:
                        # TODO: we will break hard, if the item is expired
                        value = cache.get(arg)
                        local_cache.add(arg, value)
                    real_args.append(value)
                elif isinstance(arg, list) and [True for item in arg
                                                if isinstance(item, ProcessDataCacheItemID)]:
                    # check if any item in the list is cacheable
                    args_list = []
                    for item in arg:
                        if isinstance(item, ProcessDataCacheItemID):
                            try:
                                value = local_cache.get(item)
                            except KeyError:
                                value = cache.get(item)
                                local_cache.add(item, value)
                            args_list.append(value)
                        else:
                            args_list.append(item)
                    real_args.append(args_list)
                else:
                    real_args.append(arg)
            stats.add_transfer_time(name, time.time() - start_time)
            start_time = time.time()
            results.put((job_id, task_id, func(real_args)))
            pending_tasks.remove(job_id, task_id)
            stats.add_process_time(name, time.time() - start_time)
    except KeyboardInterrupt:
        pass
    log.debug("Worker thread finished after %d seconds of inactivity: %s", timeout_counter, name)


def run_in_parallel_remote(func, args_list, unordered=False, disable_multiprocessing=False,
                           callback=None):
    global __multiprocessing, __num_of_processes, __manager, __task_source_uuid, __finished_jobs
    if __multiprocessing is None:
        # threading was not configured before
        init_threading()
    if __multiprocessing and not disable_multiprocessing:
        job_id = str(uuid.uuid1())
        log.debug("Starting parallel tasks: %s", job_id)
        tasks_queue = __manager.tasks()
        results_queue = __manager.results()
        remote_cache = __manager.cache()
        stats = __manager.statistics()
        pending_tasks = __manager.pending_tasks()
        # add all tasks of this job to the queue
        for index, args in enumerate(args_list):
            if callback:
                callback()
            start_time = time.time()
            result_args = []
            for arg in args:
                # add the argument to the cache if possible
                if hasattr(arg, "uuid"):
                    data_uuid = ProcessDataCacheItemID(arg.uuid)
                    if not remote_cache.contains(data_uuid):
                        log.debug("Adding cache item for job %s: %s - %s",
                                  job_id, arg.uuid, arg.__class__)
                        remote_cache.add(data_uuid, arg)
                    result_args.append(data_uuid)
                elif isinstance(arg, (list, set, tuple)):
                    # a list with - maybe containing cacheable items
                    new_arg_list = []
                    for item in arg:
                        try:
                            data_uuid = ProcessDataCacheItemID(item.uuid)
                        except AttributeError:
                            # non-cacheable item
                            new_arg_list.append(item)
                            continue
                        if not remote_cache.contains(data_uuid):
                            log.debug("Adding cache item from list for job %s: %s - %s",
                                      job_id, item.uuid, item.__class__)
                            remote_cache.add(data_uuid, item)
                        new_arg_list.append(data_uuid)
                    result_args.append(new_arg_list)
                else:
                    result_args.append(arg)
            tasks_queue.put((job_id, index, func, result_args))
            stats.add_queueing_time(__task_source_uuid, time.time() - start_time)
        log.debug("Added %d tasks for job %s", len(args_list), job_id)
        result_buffer = {}
        index = 0
        cancelled = False
        # wait for all results of this job
        while (index < len(args_list)) and not cancelled:
            if callback and callback():
                # cancel requested
                cancelled = True
                break
            # re-inject stale tasks if necessary
            stale_task = pending_tasks.get_stale_task()
            if stale_task:
                stale_job_id, stale_task_id = stale_task[:2]
                if stale_job_id in __finished_jobs:
                    log.debug("Throwing away stale task of an old job: %s", stale_job_id)
                    pending_tasks.remove(stale_job_id, stale_task_id)
                elif stale_job_id == job_id:
                    log.debug("Reinjecting stale task: %s / %s", job_id, stale_task_id)
                    stale_func, stale_args = stale_task[2]
                    tasks_queue.put((job_id, stale_task_id, stale_func, stale_args))
                    pending_tasks.remove(job_id, stale_task_id)
                else:
                    # non-local task
                    log.debug("Ignoring stale non-local task: %s / %s",
                              stale_job_id, stale_task_id)
            try:
                result_job_id, task_id, result = results_queue.get(timeout=1.0)
            except queue.Empty:
                time.sleep(1.0)
                continue
            if result_job_id == job_id:
                log.debug("Received the result of a task: %s / %s", job_id, task_id)
                try:
                    if unordered:
                        # just return the values in any order
                        yield result
                        index += 1
                    else:
                        # return the results in order (based on task_id)
                        if task_id == index:
                            yield result
                            index += 1
                            while index in result_buffer.keys():
                                yield result_buffer[index]
                                del result_buffer[index]
                                index += 1
                        else:
                            result_buffer[task_id] = result
                except GeneratorExit:
                    # This exception is triggered when the caller stops
                    # requesting more items from the generator.
                    log.debug("Parallel processing cancelled: %s", job_id)
                    _cleanup_job(job_id, tasks_queue, pending_tasks, __finished_jobs)
                    # re-raise the GeneratorExit exception to finish destruction
                    raise
            elif result_job_id in __finished_jobs:
                # throw away this result of an old job
                log.debug("Throwing away one result of an old job: %s", result_job_id)
            else:
                log.debug("Skipping result of non-local job: %s", result_job_id)
                # put the result back to the queue for the next manager
                results_queue.put((result_job_id, task_id, result))
                # wait a little bit to get some idle CPU cycles
                time.sleep(0.2)
        _cleanup_job(job_id, tasks_queue, pending_tasks, __finished_jobs)
        if cancelled:
            log.debug("Parallel processing cancelled: %s", job_id)
        else:
            log.debug("Parallel processing finished: %s", job_id)
    else:
        for args in args_list:
            yield func(args)


def _cleanup_job(job_id, tasks_queue, pending_tasks, finished_jobs):
    # flush the task queue
    try:
        queue_len = tasks_queue.qsize()
    except NotImplementedError:
        # this can happen on MacOS (according to the multiprocessing doc)
        # -> no cleanup of old processes
        queue_len = 0
    # remove all remaining tasks with the current job id
    removed_job_counter = 0
    for index in range(queue_len):
        try:
            this_job_id, task_id, func, args = tasks_queue.get(timeout=0.1)
        except queue.Empty:
            break
        if this_job_id != job_id:
            tasks_queue.put((this_job_id, task_id, func, args))
        else:
            removed_job_counter += 1
    if removed_job_counter > 0:
        log.debug("Removed %d remaining tasks for %s", removed_job_counter, job_id)
    # remove all stale tasks
    pending_tasks.remove(job_id)
    # limit the number of stored finished jobs
    finished_jobs.append(job_id)
    while len(finished_jobs) > 30:
        finished_jobs.pop(0)


def run_in_parallel_local(func, args, unordered=False, disable_multiprocessing=False,
                          callback=None):
    global __multiprocessing, __num_of_processes
    if __multiprocessing is None:
        # threading was not configured before
        init_threading()
    if __multiprocessing and not disable_multiprocessing:
        # use the number of CPUs as the default number of worker threads
        pool = __multiprocessing.Pool(__num_of_processes)
        if unordered:
            imap_func = pool.imap_unordered
        else:
            imap_func = pool.imap
        # We need to use try/finally here to ensure the garbage collection
        # of "pool". Otherwise a memory overflow is caused for Python 2.7.
        try:
            # Beware: we may not return "pool.imap" or "pool.imap_unordered"
            # directly. It would somehow loose the focus and just hang infinitely.
            # Thus we wrap our own generator around it.
            for result in imap_func(func, args):
                if callback and callback():
                    # cancel requested
                    break
                yield result
        finally:
            pool.terminate()
    else:
        for arg in args:
            if callback and callback():
                # cancel requested
                break
            yield func(arg)


class OneProcess:
    def __init__(self, name, is_queue=False):
        self.is_queue = is_queue
        self.name = name
        self.transfer_time = 0
        self.transfer_count = 0
        self.process_time = 0
        self.process_count = 0

    def __str__(self):
        try:
            if self.is_queue:
                return "Queue %s: %s (%s/%s)" % (self.name, self.transfer_time/self.transfer_count,
                                                 self.transfer_time, self.transfer_count)
            else:
                return "Process %s: %s (%s/%s) - %s (%s/%s)" % (
                    self.name, self.transfer_time/self.transfer_count, self.transfer_time,
                    self.transfer_count, self.process_time/self.process_count, self.process_time,
                    self.process_count)
        except ZeroDivisionError:
            # race condition between adding new objects and output
            if self.is_queue:
                return "Queue %s: not ready" % str(self.name)
            else:
                return "Process %s: not ready" % str(self.name)


class ProcessStatistics:

    def __init__(self, timeout=120):
        self.processes = {}
        self.queues = {}
        self.workers = {}
        self.timeout = timeout

    def __str__(self):
        return os.linesep.join([str(item)
                                for item in self.processes.values() + self.queues.values()])

    def _refresh_workers(self):
        oldest_valid = time.time() - self.timeout
        # be careful: the workers dictionary can be changed within the loop
        for key, timestamp in list(self.workers.items()):
            if timestamp < oldest_valid:
                try:
                    del self.workers[key]
                except KeyError:
                    pass

    def get_stats(self):
        return str(self)

    def add_transfer_time(self, name, amount):
        if name not in self.processes.keys():
            self.processes[name] = OneProcess(name)
        self.processes[name].transfer_count += 1
        self.processes[name].transfer_time += amount

    def add_process_time(self, name, amount):
        if name not in self.processes.keys():
            self.processes[name] = OneProcess(name)
        self.processes[name].process_count += 1
        self.processes[name].process_time += amount

    def add_queueing_time(self, name, amount):
        if name not in self.queues.keys():
            self.queues[name] = OneProcess(name, is_queue=True)
        self.queues[name].transfer_count += 1
        self.queues[name].transfer_time += amount

    def worker_notification(self, name):
        timestamp = time.time()
        self.workers[name] = timestamp

    def get_worker_statistics(self):
        self._refresh_workers()
        now = time.time()
        result = []
        # Cache the key list instead of iterating it - otherwise a
        # "RuntimeError: dictionary changed size during iteration" may occur.
        for key, worker_start_time in list(self.workers.items()):
            try:
                one_process = self.processes[key]
                last_notification = int(now - worker_start_time)
            except KeyError:
                # no data available yet or the item was removed meanwhile
                continue
            num_of_tasks = one_process.process_count
            process_time = one_process.process_time
            # avoid divide-by-zero
            avg_process_time = process_time / max(1, num_of_tasks)
            avg_transfer_time = one_process.transfer_time / max(1, num_of_tasks)
            result.append((key, last_notification, num_of_tasks, process_time, avg_process_time,
                           avg_transfer_time))
        return result


class PendingTasks:

    def __init__(self, stale_timeout=300):
        # we assume that multiprocessing was imported before
        import multiprocessing
        self._lock = multiprocessing.Lock()
        self._jobs = {}
        self._stale_timeout = stale_timeout
        # necessary in case of a lost connection
        self._lock_timeout = 3

    def add(self, job_id, task_id, info):
        # no acquire and release: be as quick as possible (avoid lost tasks)
        self._jobs[(job_id, task_id)] = (time.time(), info)

    def remove(self, job_id, task_id=None):
        self._lock.acquire(block=True, timeout=self._lock_timeout)
        if task_id is None:
            # remove all tasks of this job
            remove_keys = []
            for key in list(self._jobs.keys()):
                if key[0] == job_id:
                    remove_keys.append(key)
            for key in remove_keys:
                try:
                    del self._jobs[key]
                except KeyError:
                    # maybe they were removed in between
                    pass
        else:
            # remove only a specific task
            if (job_id, task_id) in self._jobs:
                del self._jobs[(job_id, task_id)]
        self._lock.release()

    def get_stale_task(self):
        self._lock.acquire(block=True, timeout=self._lock_timeout)
        stale_start_time = time.time() - self._stale_timeout
        stale_tasks = []
        # use a copy to prevent "dictionary changed size in iteration" errors
        current_jobs = list(self._jobs.items())
        for (job_id, task_id), (start_time, info) in current_jobs:
            if start_time < stale_start_time:
                stale_tasks.append((job_id, task_id, info))
        if stale_tasks:
            # pick a random task - otherwise some old tasks stop everything
            result_index = random.randrange(0, len(stale_tasks))
            result = stale_tasks[result_index]
        else:
            result = None
        self._lock.release()
        return result

    def length(self):
        return len(self._jobs)


class ProcessDataCache:

    def __init__(self, timeout=600):
        self.cache = {}
        self.timeout = timeout

    def _update_timestamp(self, name):
        if isinstance(name, ProcessDataCacheItemID):
            name = name.value
        now = time.time()
        try:
            self.cache[name][1] = now
        except KeyError:
            # the item was deleted meanwhile
            pass

    def expire_cache_items(self):
        expired = time.time() - self.timeout
        # use a copy in order to avoid "changed size during iteration" errors
        for key in list(self.cache):
            try:
                if self.cache[key][1] < expired:
                    del self.cache[key]
            except KeyError:
                # ignore removed items
                pass

    def contains(self, name):
        if isinstance(name, ProcessDataCacheItemID):
            name = name.value
        self._update_timestamp(name)
        self.expire_cache_items()
        return name in self.cache.keys()

    def add(self, name, value):
        now = time.time()
        if isinstance(name, ProcessDataCacheItemID):
            name = name.value
        self.expire_cache_items()
        self.cache[name] = [value, now]

    def get(self, name):
        if isinstance(name, ProcessDataCacheItemID):
            name = name.value
        self._update_timestamp(name)
        self.expire_cache_items()
        return self.cache[name][0]

    def length(self):
        return len(self.cache)


class ProcessDataCacheItemID:

    def __init__(self, value):
        self.value = value
