FROM ghcr.io/actions/actions-runner:2.337.0@sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4

ARG GH_VERSION=2.89.0

USER root
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL -o /tmp/gh.deb \
         "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.deb" \
    && dpkg -i /tmp/gh.deb \
    && rm /tmp/gh.deb

# dirmngr is required by sonarqube-scan-action v8+ which verifies the
# scanner binary signature via GPG keyserver lookups before running.
RUN apt-get update \
    && apt-get install -y --no-install-recommends dirmngr \
    && rm -rf /var/lib/apt/lists/*
USER runner
