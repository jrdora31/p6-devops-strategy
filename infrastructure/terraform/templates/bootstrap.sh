#!/usr/bin/env bash
set -euo pipefail

# Ce bootstrap contient uniquement les prérequis nécessaires pour que Systems
# Manager puis Ansible puissent prendre le relais. K3s reste géré par Ansible.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --yes ca-certificates curl python3 unzip

if ! dpkg-query --show --showformat='${Status}' amazon-ssm-agent 2>/dev/null \
  | grep --quiet 'install ok installed'; then
  ssm_agent_package=/tmp/amazon-ssm-agent.deb
  curl --fail --location --silent --show-error \
    https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb \
    --output "$ssm_agent_package"
  apt-get install --yes "$ssm_agent_package"
  rm -f "$ssm_agent_package"
fi

systemctl enable --now amazon-ssm-agent.service
