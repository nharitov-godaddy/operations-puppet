#!/bin/bash

DATE=$(date '+%Y%m%d')

nice -n 19 sqlite3 /etc/dynamicproxy-api/data.db .dump | nice -n 19 gzip -9 > /srv/backup/proxy-${HOSTNAME}-${DATE}.bak.gz

