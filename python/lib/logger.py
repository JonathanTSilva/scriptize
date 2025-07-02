# python/script_lib/logger.py
import logging

import colorlog


def setup_logger(name='script_logger', level=logging.INFO):
    """Sets up a standardized colorized logger."""
    handler = colorlog.StreamHandler()
    handler.setFormatter(
        colorlog.ColoredFormatter(
            '%(log_color)s%(levelname)-8s%(reset)s %(message)s',
            log_colors={
                'DEBUG': 'cyan',
                'INFO': 'green',
                'WARNING': 'yellow',
                'ERROR': 'red',
                'CRITICAL': 'red,bg_white',
            },
        )
    )

    logger = colorlog.getLogger(name)
    if not logger.handlers:  # Avoid adding handlers multiple times
        logger.addHandler(handler)
    logger.setLevel(level)
    return logger


# Pre-configured logger instance
log = setup_logger()
