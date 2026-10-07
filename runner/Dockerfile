FROM ghcr.io/actions/actions-runner:2.338.0@sha256:4ffadc0002b2581327e06101fc8c06cd189232baf79fe561fac9caeb76f5e807

ARG GH_VERSION=2.102.0

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
