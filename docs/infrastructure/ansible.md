# Ansible

Ansible découvre les EC2 via AWS et SSM, puis filtre strictement le tag
`Environment=poc`. L'inventaire doit retourner exactement un hôte
`k3s_servers` et un hôte `k3s_agents` avant toute configuration.

Le playbook installe le serveur K3s, lit son jeton d'adhésion sans l'afficher,
rattache l'agent et exige exactement deux nœuds `Ready`. Un seul GitLab Agent
`microcrm-poc`, alimenté par la variable protégée `GITLAB_AGENT_TOKEN`, expose
le cluster partagé aux jobs Helm des deux namespaces.
