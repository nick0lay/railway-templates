# Tracely web UI (Next.js), production build.
#
# Built from source at a pinned commit, like the backend. TRACELY_REF picks the
# commit; keep it equal to the backend's. NEXT_PUBLIC_* values are inlined into
# the client bundle at build time, so they are build arguments.
FROM node:22-slim

ARG TRACELY_REF
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g pnpm@9

WORKDIR /app/frontend
RUN ref="${TRACELY_REF:-128a5d806704ca88fca03dff0a0215c8a557b779}" \
    && curl -fsSL "https://codeload.github.com/jwuthri-cloud/tracely-ai/tar.gz/${ref}" \
       | tar -xz --strip-components=2 --wildcards '*/frontend' \
    && rm -rf node_modules .next pnpm-workspace.yaml \
    && (pnpm install --frozen-lockfile || pnpm install --no-frozen-lockfile)

ARG NEXT_PUBLIC_AUTH_MODE=local
ARG NEXT_PUBLIC_TRACELY_PUBLIC_API=
ENV NEXT_PUBLIC_AUTH_MODE=$NEXT_PUBLIC_AUTH_MODE \
    NEXT_PUBLIC_TRACELY_PUBLIC_API=$NEXT_PUBLIC_TRACELY_PUBLIC_API \
    NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in \
    NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up \
    NEXT_PUBLIC_POSTHOG_KEY= \
    NEXT_TELEMETRY_DISABLED=1
RUN pnpm build

EXPOSE 3000
# bind :: so both Railway's public edge and the private network reach it
CMD ["sh", "-c", "exec pnpm exec next start -H :: -p ${PORT:-3000}"]
