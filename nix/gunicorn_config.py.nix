{ listen, pythonpath }:
''
import multiprocessing

workers = multiprocessing.cpu_count() * 2 + 1
bind = "${listen}"

proc_name = "eviction-tracker"
pythonpath = "${pythonpath}"
timeout = 120
statsd-host = "localhost:8125"
''