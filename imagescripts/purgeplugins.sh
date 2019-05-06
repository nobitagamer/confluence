#!/bin/bash
#
# A cleaning script.
#
# Purges Confluence plugin cache.
#

set -o errexit

[[ ${DEBUG} == true ]] && set -x

if [ -d "${CONF_HOME}/bundled-plugins" ]; then
  rm -rf ${CONF_HOME}/bundled-plugins
fi

if [ -d "${CONF_HOME}/plugins-osgi-cache" ]; then
  rm -rf ${CONF_HOME}/plugins-osgi-cache
fi
