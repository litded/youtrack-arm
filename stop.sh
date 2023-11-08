#!/bin/bash

set -e

cd /opt/youtrack

exec /bin/bash ./bin/youtrack.sh stop "$@"
