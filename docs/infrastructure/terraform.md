# Terraform

Terraform conserve le réseau AWS commun dans le root `network/` et le state
`microcrm-network`. Le root parent utilise l'unique state `microcrm-poc` pour
les deux EC2 du cluster K3s partagé et le Network Load Balancer.

Le cluster contient un serveur/control-plane dédié aux workloads staging et un
agent dédié aux workloads production. Les tags `EnvironmentRole` et les labels
Kubernetes rendent ce placement reproductible. Le control-plane reste partagé :
il ne s'agit pas de deux clusters indépendants.

Terraform crée deux dashboards CloudWatch, les groupes de logs à rétention de
trois jours et des alarmes sans automatisation de promotion ou d'abandon. Les
widgets utilisent les deux InstanceId produits par le module compute.

La migration du state historique doit être contrôlée avant tout apply. Le
destroy de `microcrm-poc` est une action d'infrastructure explicite ; aucun
déploiement applicatif staging ou production ne détruit le cluster.
