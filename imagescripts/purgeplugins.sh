#!/bin/bash
#
# A cleaning script.
#
# Purges Confluence plugin cache.
#

set -o errexit

[[ ${DEBUG} == true ]] && set -x

if [ -d "${CONFLUENCE_HOME}/bundled-plugins" ]; then
  rm -rf ${CONFLUENCE_HOME}/bundled-plugins
fi

if [ -d "${CONFLUENCE_HOME}/plugins-osgi-cache" ]; then
  rm -rf ${CONFLUENCE_HOME}/plugins-osgi-cache
fi
