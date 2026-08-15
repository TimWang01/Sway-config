#!/usr/bin/env bash
set -euo pipefail

RELEASE="$(rpm -E %fedora)"

sudo curl -sL -o /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:erikreider:swayosd.repo \
  "https://copr.fedorainfracloud.org/coprs/erikreider/swayosd/repo/fedora-${RELEASE}/erikreider-swayosd-fedora-${RELEASE}.repo"

rpm-ostree install swayosd
