#!/bin/bash
# Map Railway's dynamic PORT to QuestDB's Web Console + REST API port
export QDB_HTTP_NET_BIND_TO="0.0.0.0:${PORT:-9000}"

# Increase vm.max_map_count for QuestDB memory-mapped file operations
# QuestDB recommends 1048576; default 65530 triggers a warning in the web console
# This may fail on environments without sysctl privileges — QuestDB still works, just with a warning
sysctl -w vm.max_map_count=1048576 2>/dev/null || true

# Delegate to QuestDB's original entrypoint
exec /docker-entrypoint.sh "$@"
