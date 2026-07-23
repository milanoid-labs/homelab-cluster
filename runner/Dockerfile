FROM ghcr.io/actions/actions-runner:2.336.0@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda

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
