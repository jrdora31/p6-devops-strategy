# Terraform

Terraform conserve le réseau AWS commun dans le root `network/` et le state
`microcrm-network`. Le root parent décrit une pile d'environnement réutilisée
avec deux states indépendants : `microcrm-staging` et `microcrm-production`.

Chaque pile d'environnement crée une EC2 Debian 12 avec IAM/SSM, un K3s, un
bucket temporaire Ansible et, lorsqu'il est activé, un monitoring CloudWatch
isolé. Le VPC, le subnet public et le Security Group restent partagés.

La migration du state historique doit être contrôlée avant tout apply. Un
destroy staging ou production ne doit jamais cibler `microcrm-network` ni le
state de l'autre environnement.
