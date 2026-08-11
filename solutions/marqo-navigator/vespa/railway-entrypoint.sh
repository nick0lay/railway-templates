#!/bin/bash
# Selects the Vespa role, and caps the CPU count Vespa sizes itself from.
#
# ROLE
# ----
# The upstream image declares ENTRYPOINT ["/usr/local/bin/start-container.sh"]
# and no CMD, taking the role as its single argument. Railway's "Custom Start
# Command" REPLACES the entrypoint rather than passing arguments to it, so
# setting it to `services` makes Railway try to exec a binary called `services`
# and the container dies with "The executable `services` could not be found".
#
# Wrapping it means both Vespa services share this image with no start command
# at all — the role is just a variable:
#
#   VESPA_ROLE=configserver,services   admin node (config server + services)
#   VESPA_ROLE=services                content/query node (default)
#
# There is no space after the comma; start-container.sh accepts exactly one
# argument and rejects anything else.
#
# THREAD BUDGET
# -------------
# Railway caps each container at 1000 PIDs, and Vespa sizes its jdisc thread
# pools from the host's core count — Railway hosts report 48. Untuned that puts
# the config server at 996 threads and the query container at 957, a few threads
# from the ceiling, at which point the container cannot fork at all and the
# config server stops answering.
#
# -XX:ActiveProcessorCount tells each JVM to size pools as if it had 4 cores
# without restricting which cores it may actually run on, so the pools shrink
# while throughput does not. Measured: 996 -> 497 and 957 -> 430.
#
# Defaulted here rather than left to Railway variables so a deployment that
# forgets them still lands inside the budget. Override either variable to tune.
#
# The query container JVM is capped separately, in <container><nodes><jvm> in
# the application package — see vespa-init/app/services.xml. That is the one
# element Marqo's bootstrap preserves.
set -e

ROLE="${VESPA_ROLE:-services}"
CPU_MODEL="${VESPA_JVM_PROCESSOR_COUNT:-4}"

export VESPA_CONFIGSERVER_JVMARGS="${VESPA_CONFIGSERVER_JVMARGS:--XX:ActiveProcessorCount=$CPU_MODEL}"
export VESPA_CONFIGPROXY_JVMARGS="${VESPA_CONFIGPROXY_JVMARGS:--XX:ActiveProcessorCount=$CPU_MODEL}"

echo "[vespa-entrypoint] role=$ROLE | host cores=$(nproc 2>/dev/null || echo '?') | JVMs sized for $CPU_MODEL"
exec /usr/local/bin/start-container.sh "$ROLE"
