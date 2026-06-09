FROM ghcr.io/actions/actions-runner:2.335.1@sha256:08c30b0a7105f64bddfc485d2487a22aa03932a791402393352fdf674bda2c29

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
