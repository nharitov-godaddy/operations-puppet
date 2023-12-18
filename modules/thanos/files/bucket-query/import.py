#!/usr/bin/python3
# SPDX-License-Identifier: Apache-2.0

import argparse
import fileinput
import sqlite3
import sys
from contextlib import contextmanager

SCHEMAS = {
    "sizes": """
        CREATE TABLE IF NOT EXISTS blocks_sizes (
            ULID TEXT PRIMARY KEY,
            SIZE_MB REAL
        );
    """,
    "blocks": """
        CREATE TABLE IF NOT EXISTS blocks (
            ULID TEXT PRIMARY KEY,
            FROM_TIMESTAMP DATETIME,
            UNTIL_TIMESTAMP DATETIME,
            RANGE TEXT,
            UNTIL_DOWN TEXT,
            SERIES INTEGER,
            SAMPLES INTEGER,
            CHUNKS INTEGER,
            COMP_LEVEL INTEGER,
            COMP_FAILED INTEGER,
            LABELS TEXT,
            RESOLUTION TEXT,
            SOURCE TEXT
        );
    """,
}

INSERTS = {
    "sizes": """
        INSERT INTO blocks_sizes (
            ULID, SIZE_MB
        ) VALUES (?, ?);
        """,
    "blocks": """
        INSERT INTO blocks (
            ULID, FROM_TIMESTAMP, UNTIL_TIMESTAMP, RANGE, UNTIL_DOWN, SERIES,
            SAMPLES, CHUNKS, COMP_LEVEL, COMP_FAILED, LABELS, RESOLUTION, SOURCE
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """,
}


@contextmanager
def get_or_create(path):
    conn = sqlite3.connect(path)
    cursor = conn.cursor()

    for s in ["blocks", "sizes"]:
        cursor.execute(SCHEMAS[s])
        conn.commit()

    try:
        yield conn
    finally:
        conn.close()


def import_data(conn, data_type):
    for i, line in enumerate(fileinput.input()):
        if i == 0:
            continue
        data = line.strip().split("\t")
        insert_query = INSERTS[data_type]
        conn.cursor().execute(insert_query, data)
    conn.commit()


def main():
    parser = argparse.ArgumentParser(
        description="Import Thanos block information for later analysis.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--kind",
        dest="kind",
        default="blocks",
        choices=["blocks", "sizes"],
        help="The data type to import.",
    )
    parser.add_argument(
        "--db",
        dest="db",
        default="thanos-bucket.db",
        help="The database file to use.",
    )

    args = parser.parse_args()

    with get_or_create(args.db) as conn:
        import_data(conn, args.kind)


if __name__ == "__main__":
    sys.exit(main())
