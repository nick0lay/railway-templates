#!/bin/bash
# Selects the Vespa role from an environment variable rather than a start
# command.
#
# The upstream image declares ENTRYPOINT ["/usr/local/bin/start-container.sh"]
# and no CMD, taking the role as its single argument. Railway's "Custom Start
# Command" REPLACES the entrypoint rather than passing arguments to it, so
# setting it to `services` makes Railway try to exec a binary called `services`
# and the container dies with "The executable `services` could not be found".
#
# Wrapping it means both Vespa services share this image with no start command
# at all — the role is just a variable.
#
#   VESPA_ROLE=configserver,services   admin node (config server + services)
#   VESPA_ROLE=services                content/query node (default)
#
# Note there is no space after the comma; start-container.sh accepts exactly
# one argument and rejects anything else.
set -e
exec /usr/local/bin/start-container.sh "${VESPA_ROLE:-services}"
