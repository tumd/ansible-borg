#!/bin/bash
# This wrapper should be able to run all native borg-commands
# specifying a default repo automaticaly.

# "Strict"
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# Defaults
PATHS=(
  "/"
  "/home"
  "/root"
  "/var"
  "/etc"
  "/srv"
  "/opt"
  "/boot"
)

EXCLUDES=(
  "/dev/*"
  "/proc/*"
  "/sys/*"
  "/tmp/*"
  "/run/*"
)

CREATE_ARGS=(
  --info
  --stats
  --list
  --filter AME
  --compression auto,zstd
  --show-rc
  --exclude-caches
  --one-file-system
)

PRUNE_ARGS=(
  --list
  --stats
  --prefix '{hostname}-'
  --show-rc
)

KEEP=(
  --keep-within   2d
  --keep-daily    31
  --keep-weekly   12
  --keep-monthly  12
  --keep-yearly   10
)

# Empty by default
BORG_REPO="${BORG_REPO:-}"

# Lookup configuration-file
BCONF="${BCONF:="default"}.conf"

# Config location
CONF_PATH="$HOME/.config/borg"

# Full path to config
CONF_FILE="${CONF_PATH}/${BCONF}"

# Helpers
info() { printf '### %s ### %s\n' "$( date "+%F %T" )" "$*" >&2; }

runborg() { 
  ( set -x ; BORG_REPO=${BORG_REPO} /usr/local/bin/borg "$@" )
}

cmd_create() {
  if [ -z "$BORG_REPO" ]; then
    info "Can't do a backup without basic configuration."
    exit 1;
  fi

  EXCLUDE_ARGS=()

  for EXCLUDE in "${EXCLUDES[@]}"; do
    EXCLUDE_ARGS+=( --exclude "${EXCLUDE}" )
  done

  info "Starting backup"

  runborg create \
    "${CREATE_ARGS[@]}" \
    "${EXCLUDE_ARGS[@]}" \
    ::"{hostname}-{now}" \
    "${PATHS[@]}"
}

cmd_prune() {
  if [ -z "$BORG_REPO" ]; then
    info "Can't prune without basic configuration."
    exit 1;
  fi

  info "Pruning"

  runborg prune \
    "${PRUNE_ARGS[@]}" \
    "${KEEP[@]}" \
    ::

}

if [ -f "$CONF_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONF_FILE"
else
  info "No config-file found at '${CONF_FILE}'."
fi

if [ -z "$BORG_REPO" ]; then
  info "Environment-variable BORG_REPO is not set - running as a normal borg."
fi

# Very loosely trying to identify the first borg <command>.
# Find first argument that does not start with a dash (-)
# This will not work if you pass an argument with a following param to borg.
FIRSTBARG=""
for barg in "$@"
do
  if [ "${barg:0:1}" != "-" ]; then 
    FIRSTBARG="$barg"
    break
  fi
done

#info "First borg command found: '$FIRSTBARG'"

# Hijack poisitional commands and add our own.
case "$FIRSTBARG" in
  backup)
    cmd_create
    cmd_prune

    ;;
  *)
    runborg "$@"

    ;;
esac

