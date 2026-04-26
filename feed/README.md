# feed

a helm chart for kontrolplane-feed, a self-hosted rss reader

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `10` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| cnpg | object | `{"backup":{"barmanObjectStore":{},"enabled":false,"retentionPolicy":"30d","schedule":"0 0 * * *"},"database":"feed","enabled":false,"image":{"repository":"ghcr.io/cloudnative-pg/postgresql","tag":"17"},"instances":1,"nameOverride":"","owner":"feed","resources":{},"storage":{"size":"5Gi","storageClass":""}}` | cloudnativepg cluster configuration requires the cnpg operator to be installed in the cluster |
| cnpg.backup | object | `{"barmanObjectStore":{},"enabled":false,"retentionPolicy":"30d","schedule":"0 0 * * *"}` | backup configuration |
| cnpg.backup.barmanObjectStore | object | `{}` | barman object store configuration |
| cnpg.backup.retentionPolicy | string | `"30d"` | retention policy |
| cnpg.backup.schedule | string | `"0 0 * * *"` | schedule in cron format |
| cnpg.database | string | `"feed"` | database name to create |
| cnpg.image | object | `{"repository":"ghcr.io/cloudnative-pg/postgresql","tag":"17"}` | postgresql version image |
| cnpg.instances | int | `1` | number of postgresql instances |
| cnpg.nameOverride | string | `""` | name override for the cnpg cluster (defaults to fullname-db) |
| cnpg.owner | string | `"feed"` | database owner |
| config | object | `{"debug":false,"density":"default","markReadOn":"open","refreshInterval":"15m","retention":"30d","seed":false}` | application configuration |
| config.debug | bool | `false` | enable debug logging |
| config.density | string | `"default"` | list row density: "tight", "default", or "loose" |
| config.markReadOn | string | `"open"` | when items become read: "scroll", "open", or "manual" |
| config.refreshInterval | string | `"15m"` | feed refresh interval (e.g. 15m, 1h) |
| config.retention | string | `"30d"` | keep read items for: "7d", "30d", "90d", or "forever" |
| config.seed | bool | `false` | seed default feeds on startup |
| database | object | `{"driver":"sqlite","postgres":{"database":"feed","existingSecret":"","host":"","password":"","port":"5432","sslMode":"disable","user":"feed"},"sqlite":{"path":"/data/feed.db","persistence":{"accessModes":["ReadWriteOnce"],"enabled":true,"size":"1Gi","storageClass":""}}}` | database configuration |
| database.driver | string | `"sqlite"` | database driver: "sqlite" or "postgres" |
| database.postgres | object | `{"database":"feed","existingSecret":"","host":"","password":"","port":"5432","sslMode":"disable","user":"feed"}` | postgresql configuration (only used when driver is "postgres") |
| database.postgres.existingSecret | string | `""` | use an existing secret for database credentials the secret must contain the keys: DATABASE_HOST, DATABASE_PORT, DATABASE_NAME, DATABASE_USER, DATABASE_PASSWORD, DATABASE_SSL_MODE |
| database.sqlite | object | `{"path":"/data/feed.db","persistence":{"accessModes":["ReadWriteOnce"],"enabled":true,"size":"1Gi","storageClass":""}}` | sqlite configuration (only used when driver is "sqlite") |
| database.sqlite.path | string | `"/data/feed.db"` | path inside the container for the sqlite database file |
| database.sqlite.persistence | object | `{"accessModes":["ReadWriteOnce"],"enabled":true,"size":"1Gi","storageClass":""}` | persistence for sqlite data |
| database.sqlite.persistence.storageClass | string | `""` | storage class for the pvc (empty string uses the default) |
| extraEnv | list | `[]` | additional environment variables |
| extraEnvFrom | list | `[]` | additional environment variables from secrets or configmaps |
| feeds | list | `[]` | feeds to import on startup (OPML format rendered from this list) when set, the default seed feeds are skipped unless config.seed is true |
| fullnameOverride | string | `""` |  |
| httpRoute.annotations | object | `{}` |  |
| httpRoute.enabled | bool | `false` |  |
| httpRoute.hostnames[0] | string | `"feed.example.com"` |  |
| httpRoute.parentRefs[0].name | string | `"gateway"` |  |
| httpRoute.parentRefs[0].sectionName | string | `"http"` |  |
| httpRoute.rules[0].matches[0].path.type | string | `"PathPrefix"` |  |
| httpRoute.rules[0].matches[0].path.value | string | `"/"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"kontrolplane/feed"` |  |
| image.tag | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"feed.example.com"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.httpGet.path | string | `"/"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| livenessProbe.initialDelaySeconds | int | `5` |  |
| livenessProbe.periodSeconds | int | `10` |  |
| nameOverride | string | `""` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| readinessProbe.httpGet.path | string | `"/"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| readinessProbe.initialDelaySeconds | int | `3` |  |
| readinessProbe.periodSeconds | int | `5` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| securityContext | object | `{}` |  |
| service.port | int | `80` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automount | bool | `true` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| tolerations | list | `[]` |  |
| volumeMounts | list | `[]` | additional volume mounts |
| volumes | list | `[]` | additional volumes |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
