### Faucet Image ###
FROM debian-base AS faucet

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    sed -i 's|http://security.debian.org/debian-security|https://cloudfront.debian.net/debian-security|g' /etc/lbt/sources.list &&  \
    apt-get update && apt-get --no-install-recommends install -y \
        procps

RUN mkdir -p /creditchain/client/data/wallet/

COPY --link --from=tools-builder /creditchain/dist/creditchain-faucet-service /usr/local/bin/creditchain-faucet-service

# Mint proxy listening address
EXPOSE 8000
ENV RUST_LOG_FORMAT=json

# add build info
ARG BUILD_DATE
ENV BUILD_DATE ${BUILD_DATE}
ARG GIT_TAG
ENV GIT_TAG ${GIT_TAG}
ARG GIT_BRANCH
ENV GIT_BRANCH ${GIT_BRANCH}
ARG GIT_SHA
ENV GIT_SHA ${GIT_SHA}
