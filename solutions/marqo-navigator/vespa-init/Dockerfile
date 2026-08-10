# One-shot bootstrap: pushes the Vespa application package that defines the
# cluster topology, then exits.
#
# Marqo cannot do this itself. In external-vector-store mode it skips Vespa
# setup entirely and expects an application to already be deployed, so
# something has to lay down the initial services.xml/hosts.xml. That file is
# also where the two tunings that survive Marqo's later rewrites live — see
# app/services.xml.
FROM curlimages/curl:latest

COPY app /app
COPY deploy-app.sh /deploy-app.sh

USER root
RUN chmod +x /deploy-app.sh
USER curl_user

ENTRYPOINT ["/bin/sh", "/deploy-app.sh"]
