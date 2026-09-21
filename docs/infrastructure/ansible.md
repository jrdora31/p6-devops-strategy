# Ansible

Ansible découvre les EC2 via AWS et SSM, puis filtre strictement le tag
`Environment=poc`. L'inventaire doit retourner exactement un hôte
`k3s_servers` et un hôte `k3s_agents` avant toute configuration.

Repères dans le dépôt : [inventaire AWS](../../infrastructure/ansible/inventory/poc.aws_ec2.yml),
[playbook principal](../../infrastructure/ansible/playbooks/site.yml) et
[rôles Ansible](../../infrastructure/ansible/roles/).

Le [playbook](../../infrastructure/ansible/playbooks/site.yml) impose cette
condition avant de configurer les EC2 :

```yaml
- name: Garantir un serveur et un agent K3s dans l'environnement
  ansible.builtin.assert:
    that:
      - cluster_environment == 'poc'
      - groups.get('k3s_servers', []) | length == 1
      - groups.get('k3s_agents', []) | length == 1
```

Le playbook installe le serveur K3s, lit son jeton d'adhésion sans l'afficher,
rattache l'agent et exige exactement deux nœuds `Ready` —
[source](../../infrastructure/ansible/roles/k3s_agent/tasks/main.yml). Un seul GitLab Agent
`microcrm-poc`, alimenté par la variable protégée `GITLAB_AGENT_TOKEN`, expose
le cluster partagé aux jobs Helm des deux namespaces —
[source](../../infrastructure/ansible/roles/k3s_server/tasks/main.yml).

Le [rôle serveur](../../infrastructure/ansible/roles/k3s_server/tasks/main.yml)
lit le jeton K3s sans le journaliser. Le playbook transmet sa valeur décodée
au rôle agent, dont le [template](../../infrastructure/ansible/roles/k3s_agent/templates/config.yaml.j2)
utilise l'adresse privée du serveur et le port 6443 :

```yaml
- name: Lire le jeton d'adhésion des agents K3s
  ansible.builtin.slurp:
    src: /var/lib/rancher/k3s/server/node-token
  register: k3s_server_node_token
  no_log: true
  when: not ansible_check_mode
```

```yaml
server: "https://{{ k3s_agent_server_address }}:6443"
token: "{{ k3s_agent_token }}"
node-label:
  - "microcrm-environment={{ cluster_environment }}"
  - "microcrm-managed-by=ansible"
  - "microcrm.io/environment-role=production"
```

Le template de configuration agent contient un jeton : la tâche qui l'écrit
utilise aussi `no_log: true` et un fichier de mode `0600`.

Le serveur est labellisé `staging` et l'agent `production`. Le rôle CloudWatch
reste commun et idempotent sur les deux EC2 ; il collecte les métriques hôte,
les logs K3s/Traefik et écoute StatsD sur le port UDP 8125 du nœud —
[source](../../infrastructure/ansible/roles/cloudwatch_agent/templates/amazon-cloudwatch-agent.json.j2).

Après l'apply Terraform, les jobs `deploy:ansible:check` et
`deploy:ansible:apply` contrôlent puis appliquent cette configuration. Ils
préparent K3s sans déployer l'application.
