#!/bin/bash

# pipefail is useful
set -o pipefail

# Global variables
PROGRAM_NAME="acd-backup"
SYSLOG_TAG="${PROGRAM_NAME}"
LOCKFILE="${HOME}/tmp/${PROGRAM_NAME}-lockfile.txt"
RCLONE="/usr/local/bin/rclone"
RCLONE_FILTERS="${HOME}/.rclone-filters"
BACKUP_SRC="${HOME}/"
BACKUP_DEST="amazon:files"
TIMESTAMP="${HOME}/tmp/backup-timestamp.txt"

info() {
  /usr/bin/logger --id --priority local3.info --tag ${SYSLOG_TAG} "INFO: $@"
}

warn() {
  /usr/bin/logger --id --stderr --priority local3.warning --tag ${SYSLOG_TAG} "WARN: $@"
}

error() {
  /usr/bin/logger --id --stderr --priority local3.err --tag ${SYSLOG_TAG} "ERROR: $@"
  exit 1
}

cleanup() {
  info "Cleaning up!"
  rm -f ${LOCKFILE}
}

if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
  warn "${PROGRAM_NAME} already running"
  exit
fi

# make sure the lockfile is removed when we exit and then claim it
trap cleanup SIGHUP SIGINT SIGTERM

# echo our PID into the lockfile
echo $$ > ${LOCKFILE}

rm -f ${TIMESTAMP}

# Backup all the relevant files
${RCLONE} \
  --filter-from ${RCLONE_FILTERS} \
  --transfers 10 \
  --checkers 10 \
  --size-only \
  sync ${BACKUP_SRC} ${BACKUP_DEST} \
  2>&1 | /usr/bin/logger --id \
  --priority 'local3.info' \
  --tag "${SYSLOG_TAG}"

if [ $? -eq 0 ]; then
  info "Backup finshed successfully"
  echo `date` > ${TIMESTAMP}
else
  warn "Error completing backup"
fi

# Cleanup
cleanup
