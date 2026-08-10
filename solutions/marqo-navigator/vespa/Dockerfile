# Vespa — the vector store behind Marqo.
#
# Both Vespa services in this template build from this file and differ only in
# their start command:
#
#   vespa-admin   configserver,services   config server, log server,
#                                         cluster controller, slobrok
#   vespa-node    services                query container + content node
#
# The split exists because Railway caps each container at 1000 PIDs and a
# single all-in-one Vespa needs ~1010 at peak. Separated, the two sides run at
# roughly 600 and 550 with room to spare. See README.md "Why Vespa is split".
#
# Can be overridden by Railway environment variable `VESPA_IMAGE_TAG`.
ARG VESPA_IMAGE_TAG
FROM vespaengine/vespa:${VESPA_IMAGE_TAG:-8.431.32}

# Run as root to avoid volume permission issues (Railway recommendation).
ENV RAILWAY_RUN_UID=0

# 19071 config server / deploy API, 2181 ZooKeeper (admin role)
# 8080  query + document API                        (node role)
EXPOSE 8080 19071 2181

# Overridden per service. Defaults to the node role.
CMD ["services"]
