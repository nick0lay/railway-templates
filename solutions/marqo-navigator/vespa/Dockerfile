# Vespa — the vector store behind Marqo.
#
# Both Vespa services in this template build from this file and differ only in
# the VESPA_ROLE environment variable:
#
#   VESPA_ROLE=configserver,services   config server, ZooKeeper, log server,
#                                      cluster controller, slobrok
#   VESPA_ROLE=services                query container + content node (default)
#
# The role is a variable rather than a Railway start command on purpose: a
# custom start command replaces the image's ENTRYPOINT instead of passing
# arguments to it, which makes Railway try to exec a binary named `services`.
# See railway-entrypoint.sh.
#
# The split exists because Railway caps each container at 1000 PIDs and a
# single all-in-one Vespa needs ~1010 at peak. Separated, the two sides run at
# roughly 600 and 570 with room to spare. See README.md "Why Vespa is split".
#
# Can be overridden by Railway environment variable `VESPA_IMAGE_TAG`.
ARG VESPA_IMAGE_TAG
FROM vespaengine/vespa:${VESPA_IMAGE_TAG:-8.431.32}

# The base image runs as the `vespa` user; root is needed to install the wrapper
# and to avoid volume permission issues on Railway.
USER root
COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

ENV RAILWAY_RUN_UID=0

# 19071 config server / deploy API, 2181 ZooKeeper (admin role)
# 8080  query + document API                        (node role)
EXPOSE 8080 19071 2181

ENTRYPOINT ["/railway-entrypoint.sh"]
