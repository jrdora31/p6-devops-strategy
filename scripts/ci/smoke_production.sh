#!/usr/bin/env bash

# Vérifie l'entrée publique de production sans coder une adresse IP ou un DNS.

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: smoke_production.sh

Variables requises : AWS_REGION, NLB_NAME, NLB_TARGET_GROUP_NAME, INGRESS_HOST.
EOF
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
[[ "$#" -eq 0 ]] || { usage >&2; exit 2; }

for variable_name in AWS_REGION NLB_NAME NLB_TARGET_GROUP_NAME INGRESS_HOST; do
  [[ -n "${!variable_name:-}" ]] || {
    echo "Variable requise absente : ${variable_name}" >&2
    exit 2
  }
done

nlb_dns_name="$(aws elbv2 describe-load-balancers \
  --names "$NLB_NAME" --query 'LoadBalancers[0].DNSName' --output text)"
target_group_arn="$(aws elbv2 describe-target-groups \
  --names "$NLB_TARGET_GROUP_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text)"

[[ -n "$nlb_dns_name" && "$nlb_dns_name" != "None" ]] || {
  echo "DNS du NLB introuvable" >&2
  exit 1
}

healthy_targets="$(aws elbv2 describe-target-health \
  --target-group-arn "$target_group_arn" \
  --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
  --output text)"
[[ "$healthy_targets" -eq 2 ]] || {
  echo "Le NLB n'expose pas les deux EC2 saines (${healthy_targets})" >&2
  exit 1
}

curl --fail --silent --show-error --retry 6 --retry-delay 10 \
  --header "Host: $INGRESS_HOST" "http://$nlb_dns_name/" --output /dev/null
curl --fail --silent --show-error --retry 6 --retry-delay 10 \
  --header "Host: $INGRESS_HOST" "http://$nlb_dns_name/api/persons" --output /dev/null

echo "Smoke HTTP de la production via NLB réussi"
