#!/bin/bash

set -e

usage() {
    echo "usage: ${0} [options] DOMAIN_LIST_NAME"
    echo "options:"
    echo "   -s: delay seconds(sleep 0-n seconds at random). "
}

SLEEP_MAX=0
param=()

echo "==== $(date) =========================================================="

set -x

for OPT in "$@"
do
    case "$OPT" in
        '-h'|'--help' )
            usage
            exit 1
            ;;
        '-s' )
            SLEEP_MAX="$2"
            shift 2
            ;;
        '--'|'-' )
            shift 1
            param+=( "$@" )
            break
            ;;
        -*)
            echo "$PROGNAME: illegal option -- '$(echo $1 | sed 's/^-*//')'" 1>&2
            exit 1
            ;;
        *)
            if [[ ! -z "$1" ]] && [[ ! "$1" =~ ^-+ ]]; then
                param+=( "$1" )
                shift 1
            fi
            ;;
    esac
done

DOMAIN_LIST_NAME=${param[0]} || ''

if [ "$DOMAIN_LIST_NAME" == '' ]; then
    echo 'DOMAIN_LIST_NAME not specified.'
    exit 1
fi

if [ ! -f "${DOMAIN_LIST_NAME}" ]; then
    echo "File does not exist: ${DOMAIN_LIST_NAME}"
    exit 1
fi

for DOMAIN_NAME in $(cat ${DOMAIN_LIST_NAME}); do
    if [ $SLEEP_MAX -gt 1 ]; then
        SLEEP_SECONDS=$(( $RANDOM % $SLEEP_MAX + 1))
        echo "Sleep ${SLEEP_SECONDS} seconds."
        sleep ${SLEEP_SECONDS}s
    fi

    /usr/local/letsencrypt/dehydrated --cron --domain $DOMAIN_NAME
done

/usr/local/nginx/sbin/nginx -s reload
