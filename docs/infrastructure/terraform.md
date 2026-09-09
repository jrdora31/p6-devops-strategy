# Terraform

Terraform conserve le réseau AWS commun dans le root `network/` et le state
`microcrm-network`. Le root parent utilise l'unique state `microcrm-poc` pour
les deux EC2 du cluster K3s partagé et le Network Load Balancer.

Le cluster contient un serveur/control-plane et un agent. Les deux nœuds
peuvent exécuter les workloads. Staging et production restent séparés par
leurs namespaces Helm, pas par des EC2 ou des clusters distincts.

La migration du state historique doit être contrôlée avant tout apply. Le
destroy de `microcrm-poc` est une action d'infrastructure explicite ; aucun
déploiement applicatif staging ou production ne détruit le cluster.
