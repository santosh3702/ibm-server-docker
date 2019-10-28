#!/bin/bash

set -e

QMGR_EXISTS=`dspmq | grep ${MQ_QMGR_NAME} > /dev/null ; echo $?`

if [ ${QMGR_EXISTS} -ne 0 ]; then
  MQ_DEV=${MQ_DEV:-"true"}
  if [ "${MQ_DEV}" == "true" ]; then
    # Turns on early adopt if we're using Developer defaults
    export AMQ_EXTRA_QM_STANZAS=Channels:ChlauthEarlyAdopt=Y
  fi
  crtmqm -q ${MQ_QMGR_NAME} || true
fi
