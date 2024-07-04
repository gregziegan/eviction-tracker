import os
from .util import RequestIdFilter

LOGGING = {
    "version": 1,
    "disable_existing_loggers": True,
    "filters": {"request_id_filter": {"()": RequestIdFilter}},
    "formatters": {
        "standard": {"format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s"},
        "json": {
            "class": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "format": "%(asctime)s %(name)s %(levelname)s %(request_id)s %(message)s",
        },
        "debug_json": {
            "class": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "format": "%(asctime)s %(name)s %(levelname)s %(message)s %(process)s %(processName)s %(pathname)s %(lineno)s",
        },
    },
    "handlers": {
        "file": {
            "class": "logging.handlers.RotatingFileHandler",
            "level": "DEBUG",
            "formatter": "json",
            "filename": "capture.log",
            "filters": ["request_id_filter"],
        }
    },
    "loggers": {
        "": {"handlers": ["file"], "level": "INFO", "propagate": False},  # root logger
        "gunicorn": {
            "level": "INFO",
            "handlers": ["file"],
            "propagate": True,
        },
        "rdc_website.app": {
            "handlers": ["file"],
            "level": "INFO",
            "propagate": False,
        },
        "rdc_website.commands": {
            "handlers": ["file"],
            "level": "INFO",
            "propagate": False,
        },
        "rdc_website.jobs": {
            "handlers": ["file"],
            "level": "INFO",
            "propagate": False,
        },
        "rdc_website.detainer_warrants.caselink.common": {
            "handlers": ["file"],
            "level": "INFO",
            "propagate": False,
        },
        "rdc_website.detainer_warrants.caselink.warrants": {
            "handlers": ["file"],
            "level": "INFO",
            "propagate": False,
        },
        "rdc_website.detainer_warrants.caselink.pleadings": {
            "handlers": ["file"],
            "level": "INFO",
            "propagate": False,
        },
    },
}
