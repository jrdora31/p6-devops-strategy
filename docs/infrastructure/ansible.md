# Ansible

Ansible découvre l'EC2 via AWS et SSM, puis filtre strictement le tag
`Environment` transmis par le state Terraform. L'inventaire doit retourner
exactement un hôte `k3s_servers` avant toute configuration.

Le même playbook installe K3s sur staging ou production. Il applique un label
de nœud propre à l'environnement et un GitLab Agent distinct ; le token est
fourni par une variable GitLab protégée spécifique à l'environnement.
