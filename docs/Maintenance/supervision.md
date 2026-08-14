Comment surveiller MicroCRM une fois déployé et diagnostiquer son état ?


- Dashboard CloudWatch
- métriques EC2
- métriques / health checks du Load Balancer
- logs applicatifs
- requêtes CloudWatch Logs Insights
- alarmes
- état K3s / pods
- commandes de diagnostic utiles

j'ai regardé les métriques, je les ai interprétées et j'en ai tiré des améliorations.

supervision.md
    ↓
ce que j'observe