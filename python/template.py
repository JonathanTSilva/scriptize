#!/usr/bin/env python3
"""
SYNOPSIS
      template.py [OPTIONS] ...

DESCRIPTION
      A brief description of this Python script.

OPTIONS
      -v, --verbose     Enable verbose output
      --version         Show program's version number and exit
"""

import logging

from script_lib.arg_parser import create_standard_parser
from script_lib.logger import setup_logger


def main():
    """Main function"""
    # Setup argument parser
    parser = create_standard_parser()
    # Add script-specific arguments here
    # parser.add_argument('--my-arg', required=True, help='An example argument.')
    args = parser.parse_args()

    # Setup logger
    log_level = logging.DEBUG if args.verbose else logging.INFO
    log = setup_logger('my_script', level=log_level)

    log.info('Script starting...')
    log.debug('This is a debug message.')
    log.warning('This is a warning.')
    log.error('This is an error.')

    try:
        # --- YOUR MAIN LOGIC GOES HERE ---
        pass
    except Exception as e:
        log.critical(f'A critical error occurred: {e}')
        return 1

    log.info('Script finished successfully.')
    return 0


if __name__ == '__main__':
    # It's good practice to handle KeyboardInterrupt gracefully
    try:
        exit_code = main()
        exit(exit_code)
    except KeyboardInterrupt:
        print('\nScript interrupted by user.')
        exit(1)
