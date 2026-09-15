"""Garde-fous statiques des choix d'infrastructure critiques du POC.

Ces tests ne prétendent pas remplacer un plan Terraform, un rendu Helm ou un
déploiement AWS. Ils détectent tôt les régressions de configuration les plus
dangereuses : retour à Ubuntu, inversion staging/production, réplication naïve
de PostgreSQL ou retrait d'un nœud du NLB.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TERRAFORM_MAIN = (ROOT / "infrastructure/terraform/main.tf").read_text(
    encoding="utf-8"
)
COMPUTE_MAIN = (
    ROOT / "infrastructure/terraform/modules/compute/main.tf"
).read_text(encoding="utf-8")
HELM_VALUES = (ROOT / "infrastructure/helm/microcrm/values.yaml").read_text(
    encoding="utf-8"
)
STAGING_VALUES = (
    ROOT / "infrastructure/helm/microcrm/values-staging.yaml"
).read_text(encoding="utf-8")
PRODUCTION_VALUES = (
    ROOT / "infrastructure/helm/microcrm/values-production.yaml"
).read_text(encoding="utf-8")
DATABASE_TEMPLATE = (
    ROOT / "infrastructure/helm/microcrm/templates/database-statefulset.yaml"
).read_text(encoding="utf-8")
DEPLOY_CI = (ROOT / ".gitlab/ci/deploy.yml").read_text(encoding="utf-8")
ANSIBLE_COMMON = (
    ROOT / "infrastructure/ansible/roles/common/tasks/main.yml"
).read_text(encoding="utf-8")
BOOTSTRAP = (ROOT / "infrastructure/terraform/templates/bootstrap.sh").read_text(
    encoding="utf-8"
)


def test_compute_selects_official_debian_12_and_ansible_rejects_other_os() -> None:
    assert 'owners      = ["136693071363"]' in COMPUTE_MAIN
    assert 'values = ["debian-12-amd64-*"]' in COMPUTE_MAIN
    assert "ansible_facts.distribution == 'Debian'" in ANSIBLE_COMMON
    assert "ansible_facts.distribution_major_version == '12'" in ANSIBLE_COMMON
    assert "apt-get install --yes" in BOOTSTRAP
    assert "amazon-ssm-agent.deb" in BOOTSTRAP


def test_two_ec2_roles_have_stable_indices_and_distinct_node_labels() -> None:
    assert 'count                       = 2' in COMPUTE_MAIN
    assert 'count.index == 0 ? "staging" : "production"' in COMPUTE_MAIN
    assert "staging    = 0" in TERRAFORM_MAIN
    assert "production = 1" in TERRAFORM_MAIN
    assert "microcrm.io/environment-role: staging" in STAGING_VALUES
    assert "microcrm.io/environment-role: production" in PRODUCTION_VALUES


def test_nlb_registers_both_role_indices_without_computed_for_each_keys() -> None:
    assert 'for_each = local.instance_roles' in TERRAFORM_MAIN
    assert 'target_id        = module.compute.instance_id[each.value]' in TERRAFORM_MAIN
    assert 'protocol    = "TCP"' in TERRAFORM_MAIN
    assert 'port              = 80' in TERRAFORM_MAIN


def test_application_is_replicated_but_postgresql_remains_single_instance() -> None:
    assert HELM_VALUES.count("replicaCount: 2") == 2
    assert "kind: StatefulSet" in DATABASE_TEMPLATE
    assert "replicas: 1" in DATABASE_TEMPLATE
    assert "volumeClaimTemplates:" in DATABASE_TEMPLATE


def test_helm_jobs_fail_closed_on_environment_target_mismatch() -> None:
    # Le contrôle est centralisé dans le template commun dont héritent staging
    # et production ; une seule occurrence est donc attendue dans le YAML.
    assert "Ciblage Helm incohérent avec l'environnement GitLab" in DEPLOY_CI
    assert (
        '"aws-poc-staging:staging:project_6_group/microcrm:microcrm-poc:'
        'microcrm-staging"' in DEPLOY_CI
    )
    assert (
        '"aws-poc-production:production:project_6_group/microcrm:microcrm-poc:'
        'microcrm-prod"' in DEPLOY_CI
    )


def test_cloudwatch_canary_metrics_are_scoped_to_production_node() -> None:
    assert TERRAFORM_MAIN.count('Environment = "production"') >= 5
    assert TERRAFORM_MAIN.count('Track       = "canary"') >= 5
    assert TERRAFORM_MAIN.count("InstanceId  = module.compute.instance_id[1]") >= 5
