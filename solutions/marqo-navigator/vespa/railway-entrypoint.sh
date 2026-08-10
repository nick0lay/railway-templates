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
# CPU CAP
# -------
# Railway hosts report 48 cores to the container. Most of Vespa's thread pools
# are fixed-size, but the ones that do scale with core count — JVM GC threads
# across four JVMs, Jetty acceptors/selectors, proton's hardware_concurrency —
# add roughly 400 threads at 48 cores versus 14. That is the difference between
# ~600 threads (fine) and hitting Railway's 1000-PID ceiling, at which point the
# container cannot fork at all and the config server stops answering.
#
# nproc, the JVM's ActiveProcessorCount and proton's hardware_concurrency all
# derive from the CPU affinity mask, so restricting affinity caps every layer at
# once — which env vars cannot do, since only the config server and config proxy
# expose JVM argument overrides.
#
# Raise VESPA_CPU_LIMIT for more throughput if the service has headroom; check
# `ps -eLo comm= | wc -l` stays comfortably under 1000 afterwards.
set -e

ROLE="${VESPA_ROLE:-services}"
CPU_LIMIT="${VESPA_CPU_LIMIT:-4}"
TOTAL_CPUS="$(nproc 2>/dev/null || echo 1)"

if command -v taskset >/dev/null 2>&1 && [ "$TOTAL_CPUS" -gt "$CPU_LIMIT" ]; then
    echo "[vespa-entrypoint] role=$ROLE — host reports ${TOTAL_CPUS} CPUs, restricting to ${CPU_LIMIT}"
    exec taskset -c "0-$((CPU_LIMIT - 1))" /usr/local/bin/start-container.sh "$ROLE"
fi

echo "[vespa-entrypoint] role=$ROLE — ${TOTAL_CPUS} CPUs, no restriction needed"
exec /usr/local/bin/start-container.sh "$ROLE"
