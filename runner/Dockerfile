FROM ghcr.io/actions/actions-runner:2.338.2@sha256:759a1d94a15b05941aba5196974ff43fe15b4cbba29b694b35cbc32a1166b232

ARG GH_VERSION=2.103.3

# apt resolves against snapshot.ubuntu.com (and the PPA's snapshot) as of this
# timestamp, so dirmngr and every dependency it pulls in are fixed. dirmngr must
# match the base image's gpgconf exactly (Depends: gpgconf (= <version>)); when a
# base image bump moves gpg, raise DIRMNGR_VERSION and the snapshot together.
ARG UBUNTU_SNAPSHOT=20261028T000000Z
ARG DIRMNGR_VERSION=2.4.4-2ubuntu17.6

USER root
# gh's .deb is checked against the checksums file from the same release.
RUN ARCH=$(dpkg --print-architecture) \
    && DEB="gh_${GH_VERSION}_linux_${ARCH}.deb" \
    && cd /tmp \
    && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${DEB}" \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" \
         | grep " ${DEB}$" | sha256sum -c - \
    && dpkg -i "${DEB}" \
    && rm "${DEB}"

# dirmngr is required by sonarqube-scan-action v8+ which verifies the
# scanner binary signature via GPG keyserver lookups before running.
RUN apt-get update --snapshot "${UBUNTU_SNAPSHOT}" \
    && apt-get install -y --no-install-recommends "dirmngr=${DIRMNGR_VERSION}" \
    && rm -rf /var/lib/apt/lists/*
USER runner
