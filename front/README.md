# Frontend MicroCRM

Application Angular 17 servie par le serveur de développement Angular en local
et par Caddy dans l’image de production.

## Développement

```shell
npm ci
npm start
```

Ouvrir `http://localhost:4200`. Le proxy de développement transmet `/api` vers
le backend configuré dans `proxy.conf.json`.

## Tests

```shell
npm test -- --watch=false --browsers=ChromeHeadless --code-coverage
```

Les tests utilisent Karma, Jasmine et Chrome. Aucun framework de test end-to-end
n’est configuré.

## Build

```shell
npm run build
```

La sortie utilisée par la CI est `dist/microcrm/browser/`. Les commandes CI
partagées sont documentées dans [`../scripts/ci/README.md`](../scripts/ci/README.md).
