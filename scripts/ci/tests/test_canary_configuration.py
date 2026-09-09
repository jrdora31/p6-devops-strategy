"""Garde-fous statiques du flow final -> Canary -> PROMOTE ou ABORT."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DEPLOY_CI = (ROOT / ".gitlab/ci/deploy.yml").read_text(encoding="utf-8")
VERIFY_CI = (ROOT / ".gitlab/ci/verify.yml").read_text(encoding="utf-8")
CANARY_SCRIPT = (ROOT / "scripts/ci/canary.sh").read_text(encoding="utf-8")
INGRESS_TEMPLATE = (
    ROOT / "infrastructure/helm/microcrm/templates/ingress.yaml"
).read_text(encoding="utf-8")
CANARY_WORKLOAD_TEMPLATE = (
    ROOT / "infrastructure/helm/microcrm/templates/canary-workloads.yaml"
).read_text(encoding="utf-8")
TERRAFORM = (ROOT / "infrastructure/terraform/main.tf").read_text(encoding="utf-8")
STATSD_CLIENT = (
    ROOT
    / "back/src/main/java/com/openclassroom/devops/orion/microcrm/CloudWatchStatsdClient.java"
).read_text(encoding="utf-8")
CLOUDWATCH_AGENT = (
    ROOT
    / "infrastructure/ansible/roles/cloudwatch_agent/templates/amazon-cloudwatch-agent.json.j2"
).read_text(encoding="utf-8")


def job_block(document: str, name: str) -> str:
    """Retourne un job top-level jusqu'au prochain job non indenté."""
    marker = f"{name}:\n"
    start = document.index(marker)
    following = document.find("\n\n", start)
    while following != -1:
        next_line = following + 2
        if next_line < len(document) and not document[next_line].isspace():
            return document[start:following]
        following = document.find("\n\n", following + 2)
    return document[start:]


def test_final_canary_deploy_is_manual_and_blocking_before_verify() -> None:
    deploy = job_block(DEPLOY_CI, "deploy:helm:production:canary")
    verify = job_block(VERIFY_CI, "verify:production:canary")

    assert "when: manual" in deploy
    assert "allow_failure: false" in deploy
    assert "-rc" not in deploy
    assert "job: deploy:helm:production:canary" in verify
    assert "when: manual" not in verify


def test_human_decisions_are_optional_jobs_after_verify() -> None:
    for name in (
        "promote:helm:production:canary",
        "abort:helm:production:canary",
    ):
        decision = job_block(VERIFY_CI, name)
        assert "stage: canary-decision" in decision
        assert "job: verify:production:canary" in decision
        assert "when: manual" in decision
        assert "allow_failure: true" in decision


def test_canary_flow_never_builds_or_retags_images() -> None:
    forbidden = ("docker build", "docker push", "gradle", "npm ", "docker tag")
    combined = DEPLOY_CI + VERIFY_CI + CANARY_SCRIPT
    assert all(command not in combined for command in forbidden)
    assert "@sha256:" in CANARY_SCRIPT


def test_traefik_weights_come_from_values() -> None:
    assert "kind: TraefikService" in INGRESS_TEMPLATE
    assert "kind: IngressRoute" in INGRESS_TEMPLATE
    assert ".Values.canary.stableWeight" in INGRESS_TEMPLATE
    assert ".Values.canary.canaryWeight" in INGRESS_TEMPLATE
    assert "doit être égale à 100" in INGRESS_TEMPLATE
    assert "stable_weight + canary_weight" in CANARY_SCRIPT


def test_canary_workloads_require_immutable_digests() -> None:
    assert "canary.frontend.image.digest est obligatoire" in CANARY_WORKLOAD_TEMPLATE
    assert "canary.backend.image.digest est obligatoire" in CANARY_WORKLOAD_TEMPLATE
    assert "^sha256:[0-9a-f]{64}$" in CANARY_WORKLOAD_TEMPLATE


def test_no_cloudwatch_observation_job_exists() -> None:
    all_ci = "\n".join(
        path.read_text(encoding="utf-8")
        for path in (ROOT / ".gitlab/ci").glob("*.yml")
    )
    assert "observation:cloudwatch:" not in all_ci


def test_application_metrics_publish_detailed_and_alarm_series() -> None:
    assert '",Track:" + track + ",Version:" + version' in STATSD_CLIENT
    assert '",Track:" + track);' in STATSD_CLIENT
    assert '"InstanceId": "${aws:InstanceId}"' in CLOUDWATCH_AGENT
    assert '"metrics_aggregation_interval": 0' in CLOUDWATCH_AGENT
    assert '"aggregation_dimensions"' not in CLOUDWATCH_AGENT

    detailed_schema = "Environment,Track,Version,InstanceId"
    assert TERRAFORM.count(detailed_schema) == 2
    assert 'InstanceId=\\"${module.compute.instance_id[1]}\\"' in TERRAFORM


def test_canary_alarms_query_the_published_rollup_series() -> None:
    # Four alarms query this rollup schema; ErrorRate contains two metric queries.
    assert TERRAFORM.count('Environment = "production"') >= 5
    assert TERRAFORM.count('Track       = "canary"') >= 5
    assert TERRAFORM.count("InstanceId  = module.compute.instance_id[1]") >= 5

    assert 'resource "aws_cloudwatch_metric_alarm" "canary_error_rate"' in TERRAFORM
    assert (
        'IF(request_count>0,100*FILL(server_errors,0)/request_count,0)'
        in TERRAFORM
    )
    assert 'metric_name = "RequestCount"' in TERRAFORM
    assert 'metric_name = "ServerErrorCount"' in TERRAFORM
