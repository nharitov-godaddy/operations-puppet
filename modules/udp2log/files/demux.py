#!/usr/bin/python3
# SPDX-License-Identifier: Apache-2.0
# THIS FILE IS MANAGED BY PUPPET

# Simple python script for demultiplexing MediaWiki log files

import argparse
import re
import sys


transTable = str.maketrans("./", "__")
openFiles = {}
nameRegex = re.compile(r"^[\040-\176]*$")

parser = argparse.ArgumentParser()
parser.add_argument(
    '--basedir',
    default='/srv/mw-log',
    help='destination path of log files'
)
args = parser.parse_args()

while True:
    # Use readline() not next() to avoid python's buffering
    line = sys.stdin.readline()
    if line == '':
        break

    try:
        name, text = line.split(" ", 1)
    except Exception:
        # No name
        continue
    str.translate(name, transTable)

    # ASCII printable?
    if not nameRegex.match(name):
        continue

    name += '.log'
    try:
        if name in openFiles:
            f = openFiles[name]
        else:
            f = open(args.basedir + '/' + name, "a")
            openFiles[name] = f
        f.write(text)
        f.flush()
    except Exception:
        # Exit if it was a ctrl-C
        if sys.exc_info()[0] == 'KeyboardInterrupt':
            break

        # Close the file and delete it from the map,
        # in case there's something wrong with it
        if name in openFiles:
            try:
                openFiles[name].close()
            except Exception:
                pass
            del openFiles[name]
