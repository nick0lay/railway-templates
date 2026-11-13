# Relay for Railway: the official image plus a static busybox, so the start
# command can write Relay's config from a variable and generate credentials
# (the official image has no shell). Everything else is set by the template.
FROM busybox:1.37.0-musl AS busybox

FROM ghcr.io/getsentry/relay:26.10.1
COPY --from=busybox /bin/busybox /bin/busybox
