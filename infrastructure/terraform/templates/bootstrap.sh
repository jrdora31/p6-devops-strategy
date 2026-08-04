#!/usr/bin/env bash
set -euo pipefail

# Ce bootstrap contient uniquement les prérequis nécessaires pour que Systems
# Manager puis Ansible puissent prendre le relais. K3s reste géré par Ansible.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --yes ca-certificates curl python3 unzip

if ! systemctl list-unit-files amazon-ssm-agent.service >/dev/null 2>&1; then
  snap install amazon-ssm-agent --classic
fi

systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service \
  || systemctl enable --now amazon-ssm-agent.service
