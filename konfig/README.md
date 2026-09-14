# konfig

a helm chart for konfig, configuration management and remote execution across fleets of machines

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

konfig manages configuration and runs commands across fleets of machines. this
chart deploys the half that lives in kubernetes:

| component | what it is |
|-----------|------------|
| controlplane | the api and the brain: reconciles the config repository, dispatches over nats, stores everything in postgres |
| console | the web client, a static bundle served by konfig's own file server |
| nats | the message bus, from the upstream [nats chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats) |
| postgresql | optional, as a [cloudnativepg](https://cloudnative-pg.io) cluster |

**agents are not deployed by this chart.** they run on the machines being
managed, installed from the `.deb`/`.rpm`, and dial the bus from outside the
cluster. see [agents](#agents) below.

## install

the chart refuses to render without the values it cannot invent for you - a
database, a session signing key, a way to sign in, and the message bus
credentials - and says which one is missing rather than crashlooping later.

```sh
helm repo add kontrolplane https://kontrolplane.github.io/helm-charts
helm install konfig kontrolplane/konfig --namespace konfig --create-namespace -f values.yaml

# or straight from the oci registry
helm install konfig oci://ghcr.io/kontrolplane/helm-charts/konfig --version 0.1.0 -f values.yaml
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://nats-io.github.io/k8s/helm/charts/ | nats | 2.14.6 |

a values.yaml that works, with the database managed by cnpg and the bus bundled:

```yaml
cnpg:
  enabled: true

controlplane:
  auth:
    # openssl rand -hex 32
    jwtSigningToken: "<32+ bytes>"
    basicAuth:
      username: admin
      password: "<a password>"
  # openssl rand -base64 32 - without it sealed secrets are off
  masterKey: "<base64, 32 bytes>"
  gitSource:
    url: https://github.com/your-org/konfig-state
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: api.konfig.example.com
        paths: [{ path: /, pathType: Prefix }]
    tls:
      - secretName: konfig-api-tls
        hosts: [api.konfig.example.com]

console:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: konfig.example.com
        paths: [{ path: /, pathType: Prefix }]
    tls:
      - secretName: konfig-tls
        hosts: [konfig.example.com]

messagebus:
  auth:
    controlplanePassword: "<a password>"
    agentPassword: "<a different password>"
```

put the secrets in a secret you manage rather than in this file where you can:
`controlplane.existingSecret`, `database.existingSecret` and
`messagebus.auth.existingSecret` each take one.

## urls

the console is a static bundle, so it is told where the api is at runtime rather
than at build time: the chart renders `/config.js` into a configmap. the
controlplane refuses cors from anywhere other than `FRONTEND_URL`. both urls are
derived from each component's ingress or httproute, so two ingresses is all it
usually takes; `urls.console` and `urls.api` override them when a proxy in front
publishes something else, and `urls.extraOrigins` adds cors origins beyond the
console.

with no ingress at all they fall back to the localhost ports `kubectl
port-forward` gives you, which is enough to try it from a laptop.

## agents

agents run on the machines you manage, so the bus has to be reachable from
outside the cluster. expose the nats service - the upstream chart takes the
whole service object under `nats.service.merge`:

```yaml
nats:
  service:
    merge:
      spec:
        type: LoadBalancer
```

then on each host, in `/etc/konfig/agent.env`:

```sh
NATS_URL=nats://agent:<messagebus.auth.agentPassword>@<the address you exposed>:4222
AGENT_TOKEN=<the organisation's enrolment token>
```

and `systemctl enable --now konfig-agent`. the token is used once: the agent
keeps its own keypair afterwards, which is what makes revoking one host possible
without rotating the fleet. set `controlplane.agents.acceptance=manual` to hold
new agents for approval.

## message bus credentials

konfig's only opinion about nats is the authorization block under
`nats.config.merge`: two users, one per role, with subject permissions. a single
shared credential would let any managed host read every organisation's events,
publish desired state - arbitrary config, therefore arbitrary code - to any
other host, and forge the events reactors act on.

the two passwords live in a secret this chart creates, and the nats subchart
reads them as environment variables the server expands. that secret is named by
a literal value, `messagebus.auth.secretName`, and not derived from the release
name, because helm cannot template a subchart's values and
`nats.container.env` has to name the same secret. **running two konfig releases
in one namespace means changing `messagebus.auth.secretName` and both
`nats.container.env[*].valueFrom.secretKeyRef.name` together**; the chart checks
that they agree and refuses to render when they do not.

to use a bus you already run, set `nats.enabled=false` and `messagebus.url`.

## database

`cnpg.enabled=true` renders a cloudnativepg `Cluster` (and a `ScheduledBackup`
when `cnpg.backup.enabled`), and the controlplane reads its connection string
from the `uri` key of the secret the operator generates. it needs the cnpg
operator in the cluster, 1.21 or newer.

otherwise set `database.url`, or `database.existingSecret` pointing at a secret
with a `DATABASE_URL` key. the controlplane runs its own migrations at startup,
under a postgres advisory lock, so a rollout does not need a migration job.

## scaling

`controlplane.replicaCount` stays at 1 on purpose: the drift loop, the retention
sweep and the schedules are not leader-elected yet, so a second replica runs
them a second time. the console is stateless and has an hpa
(`console.autoscaling`).

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| cnpg | object | `{"backup":{"barmanObjectStore":{},"enabled":false,"retentionPolicy":"30d","schedule":"0 0 * * *"},"database":"konfig","enabled":false,"image":{"repository":"ghcr.io/cloudnative-pg/postgresql","tag":"17"},"instances":1,"nameOverride":"","owner":"konfig","resources":{},"storage":{"size":"10Gi","storageClass":""}}` | cloudnativepg cluster, managed by this chart. requires the cnpg operator (>= 1.21, for the `uri` key on the generated secret) in the cluster. |
| cnpg.backup | object | `{"barmanObjectStore":{},"enabled":false,"retentionPolicy":"30d","schedule":"0 0 * * *"}` | backup configuration |
| cnpg.backup.barmanObjectStore | object | `{}` | barman object store configuration |
| cnpg.backup.retentionPolicy | string | `"30d"` | retention policy |
| cnpg.backup.schedule | string | `"0 0 * * *"` | schedule in cron format |
| cnpg.database | string | `"konfig"` | database name to create |
| cnpg.image | object | `{"repository":"ghcr.io/cloudnative-pg/postgresql","tag":"17"}` | postgresql version image |
| cnpg.instances | int | `1` | number of postgresql instances |
| cnpg.nameOverride | string | `""` | name override for the cnpg cluster (defaults to fullname-db) |
| cnpg.owner | string | `"konfig"` | database owner |
| console.affinity | object | `{}` |  |
| console.autoscaling.enabled | bool | `false` |  |
| console.autoscaling.maxReplicas | int | `5` |  |
| console.autoscaling.minReplicas | int | `1` |  |
| console.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| console.autoscaling.targetMemoryUtilizationPercentage | string | `""` |  |
| console.enabled | bool | `true` | set to false to run the api only, and serve the console yourself |
| console.extraEnv | list | `[]` |  |
| console.extraEnvFrom | list | `[]` |  |
| console.httpRoute.annotations | object | `{}` |  |
| console.httpRoute.enabled | bool | `false` |  |
| console.httpRoute.hostnames[0] | string | `"konfig.example.com"` |  |
| console.httpRoute.parentRefs[0].name | string | `"gateway"` |  |
| console.httpRoute.parentRefs[0].sectionName | string | `"http"` |  |
| console.httpRoute.rules[0].matches[0].path.type | string | `"PathPrefix"` |  |
| console.httpRoute.rules[0].matches[0].path.value | string | `"/"` |  |
| console.image.pullPolicy | string | `"IfNotPresent"` |  |
| console.image.repository | string | `"ghcr.io/kontrolplane/konfig/console"` |  |
| console.image.tag | string | `""` | overrides the image tag whose default is the chart appVersion |
| console.ingress.annotations | object | `{}` |  |
| console.ingress.className | string | `""` |  |
| console.ingress.enabled | bool | `false` |  |
| console.ingress.hosts[0].host | string | `"konfig.example.com"` |  |
| console.ingress.hosts[0].paths[0].path | string | `"/"` |  |
| console.ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| console.ingress.tls | list | `[]` |  |
| console.livenessProbe.httpGet.path | string | `"/healthz"` |  |
| console.livenessProbe.httpGet.port | string | `"http"` |  |
| console.livenessProbe.periodSeconds | int | `10` |  |
| console.logLevel | string | `"info"` |  |
| console.nodeSelector | object | `{}` |  |
| console.podAnnotations | object | `{}` |  |
| console.podDisruptionBudget.enabled | bool | `false` |  |
| console.podDisruptionBudget.maxUnavailable | string | `""` |  |
| console.podDisruptionBudget.minAvailable | int | `1` |  |
| console.podLabels | object | `{}` |  |
| console.podSecurityContext.runAsGroup | int | `65532` |  |
| console.podSecurityContext.runAsNonRoot | bool | `true` |  |
| console.podSecurityContext.runAsUser | int | `65532` |  |
| console.podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| console.priorityClassName | string | `""` |  |
| console.readinessProbe.httpGet.path | string | `"/healthz"` |  |
| console.readinessProbe.httpGet.port | string | `"http"` |  |
| console.readinessProbe.periodSeconds | int | `10` |  |
| console.replicaCount | int | `1` |  |
| console.resources | object | `{}` |  |
| console.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | nothing is written at runtime: the bundle is read-only and config.js is mounted from a configmap. |
| console.service.annotations | object | `{}` |  |
| console.service.port | int | `8080` |  |
| console.service.type | string | `"ClusterIP"` |  |
| console.startupProbe.failureThreshold | int | `20` |  |
| console.startupProbe.httpGet.path | string | `"/healthz"` |  |
| console.startupProbe.httpGet.port | string | `"http"` |  |
| console.startupProbe.periodSeconds | int | `3` |  |
| console.tolerations | list | `[]` |  |
| console.topologySpreadConstraints | list | `[]` |  |
| console.volumeMounts | list | `[]` |  |
| console.volumes | list | `[]` |  |
| controlplane.advisories | object | `{"enabled":false,"url":""}` | the patch feature: the installed-package inventory `konfig run query packages` collects, matched against advisory data. off unless asked for, because asking sends this fleet's package names and versions to a third party. point `url` at an osv-compatible mirror to get the answer without the egress. |
| controlplane.affinity | object | `{}` |  |
| controlplane.agents.acceptance | string | `""` | set to "manual" to hold newly enrolled agents for approval |
| controlplane.agents.enrolmentToken | string | `""` | enrolment token agents present to join this organisation. the organisation created on first login claims it, so a fresh deployment needs no console step. |
| controlplane.agents.token | string | `""` | global fallback token accepted from any agent, regardless of organisation. empty disables the check entirely, which is why it has no default: an unset token means any agent that can reach nats is admitted. |
| controlplane.auth.basicAuth | object | `{"enabled":true,"password":"","username":"admin"}` | username/password sign-in for the cli and the console. leave it off to offer github sign-in only; the login page renders whichever methods are configured. |
| controlplane.auth.github | object | `{"clientId":"","clientSecret":"","enabled":false}` | github oauth sign-in. the callback url is derived from `urls.api` and must match the one registered on the oauth app. |
| controlplane.auth.jwtSigningToken | string | `""` | hmac key for session tokens. required: the controlplane refuses to start without one, because an empty key verifies any session an attacker signs with it. 32 bytes or more. |
| controlplane.auth.jwtTokenExpiry | int | `72` | session lifetime in hours |
| controlplane.driftInterval | string | `""` | seconds between drift checks. 0 disables them; empty uses the binary's own default. |
| controlplane.existingSecret | string | `""` | read every secret below from an existing secret instead of the one this chart creates. the chart-managed secret is not rendered at all when this is set, and the whole secret is loaded with envFrom, so it must carry every key the deployment needs: JWT_SIGNING_TOKEN, and whichever of BASIC_AUTH_USER, BASIC_AUTH_PASSWORD, GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET, GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, AGENT_ENROLMENT_TOKEN, AGENT_TOKEN, KONFIG_MASTER_KEY apply. |
| controlplane.extraEnv | list | `[]` | additional environment variables |
| controlplane.extraEnvFrom | list | `[]` | additional environment variables from secrets or configmaps |
| controlplane.gitSource | object | `{"branch":"main","convergeOnSync":true,"installationId":"","url":""}` | point the organisation at its config repository from the chart instead of `konfig git-source set`. applied on first boot against a fresh database; edits made in the console afterwards are preserved. |
| controlplane.gitSource.convergeOnSync | bool | `true` | converge every host a sync changed config for. false syncs without dispatching. |
| controlplane.gitSource.installationId | string | `""` | github app installation id, needed for a private repository |
| controlplane.githubApp | object | `{"appId":"","privateKey":""}` | github app used to clone private config repositories |
| controlplane.githubApp.privateKey | string | `""` | pem contents of the app's private key |
| controlplane.httpRoute.annotations | object | `{}` |  |
| controlplane.httpRoute.enabled | bool | `false` |  |
| controlplane.httpRoute.hostnames[0] | string | `"api.konfig.example.com"` |  |
| controlplane.httpRoute.parentRefs[0].name | string | `"gateway"` |  |
| controlplane.httpRoute.parentRefs[0].sectionName | string | `"http"` |  |
| controlplane.httpRoute.rules[0].matches[0].path.type | string | `"PathPrefix"` |  |
| controlplane.httpRoute.rules[0].matches[0].path.value | string | `"/"` |  |
| controlplane.image.pullPolicy | string | `"IfNotPresent"` |  |
| controlplane.image.repository | string | `"ghcr.io/kontrolplane/konfig/controlplane"` |  |
| controlplane.image.tag | string | `""` | overrides the image tag whose default is the chart appVersion |
| controlplane.ingress.annotations | object | `{}` |  |
| controlplane.ingress.className | string | `""` |  |
| controlplane.ingress.enabled | bool | `false` |  |
| controlplane.ingress.hosts[0].host | string | `"api.konfig.example.com"` |  |
| controlplane.ingress.hosts[0].paths[0].path | string | `"/"` |  |
| controlplane.ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| controlplane.ingress.tls | list | `[]` |  |
| controlplane.livenessProbe.httpGet.path | string | `"/health"` |  |
| controlplane.livenessProbe.httpGet.port | string | `"http"` |  |
| controlplane.livenessProbe.periodSeconds | int | `10` |  |
| controlplane.livenessProbe.timeoutSeconds | int | `3` |  |
| controlplane.logLevel | string | `"info"` | log level: "debug", "info", "warn" or "error" |
| controlplane.masterKey | string | `""` | sealed secrets. a base64 key that decodes to 32 bytes, encrypting each organisation's sealing private key at rest. no default on purpose: this key opens every organisation's secrets, so a shipped one would be shared by every deployment that installed this chart unchanged. unset, sealed values simply fail to open. generate one with: openssl rand -base64 32 |
| controlplane.metrics | object | `{"serviceMonitor":{"enabled":false,"interval":"30s","labels":{},"metricRelabelings":[],"relabelings":[],"scrapeTimeout":""}}` | prometheus exposition for the controlplane and the fleet, on /metrics |
| controlplane.nodeSelector | object | `{}` |  |
| controlplane.podAnnotations | object | `{}` |  |
| controlplane.podDisruptionBudget.enabled | bool | `false` |  |
| controlplane.podDisruptionBudget.maxUnavailable | string | `""` |  |
| controlplane.podDisruptionBudget.minAvailable | int | `1` |  |
| controlplane.podLabels | object | `{}` |  |
| controlplane.podSecurityContext.fsGroup | int | `65532` |  |
| controlplane.podSecurityContext.runAsGroup | int | `65532` |  |
| controlplane.podSecurityContext.runAsNonRoot | bool | `true` |  |
| controlplane.podSecurityContext.runAsUser | int | `65532` |  |
| controlplane.podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| controlplane.priorityClassName | string | `""` |  |
| controlplane.readinessProbe.httpGet.path | string | `"/health"` |  |
| controlplane.readinessProbe.httpGet.port | string | `"http"` |  |
| controlplane.readinessProbe.periodSeconds | int | `10` |  |
| controlplane.readinessProbe.timeoutSeconds | int | `3` |  |
| controlplane.replicaCount | int | `1` | the controlplane runs the drift loop, the retention sweep and the schedules, and none of them are leader-elected yet: a second replica runs them a second time. keep this at 1 until konfig elects a leader. |
| controlplane.resources | object | `{}` |  |
| controlplane.retentionDays | int | `90` | task, job, orchestration-run and audit history older than this is pruned hourly. 0 keeps everything, which is what the binary defaults to; an agent on a 30-minute interval writes ~17,500 task rows a year. |
| controlplane.securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | the image already runs as 65532. a read-only root filesystem is safe because the only thing written at runtime is a clone under /tmp, which the chart mounts as an emptyDir. |
| controlplane.service.annotations | object | `{}` |  |
| controlplane.service.port | int | `10720` |  |
| controlplane.service.type | string | `"ClusterIP"` |  |
| controlplane.ssh | object | `{"existingSecret":"","knownHostsKey":"known_hosts","privateKeyKey":"id_ed25519"}` | ssh key for hosts that cannot run an agent. the secret is mounted read-only and must hold the keys named below. |
| controlplane.startupProbe | object | `{"failureThreshold":60,"httpGet":{"path":"/health","port":"http"},"periodSeconds":5}` | the controlplane runs migrations before it serves, so the startup probe is what tolerates a slow first boot and the liveness probe stays tight. |
| controlplane.terminationGracePeriodSeconds | int | `30` |  |
| controlplane.tmpSizeLimit | string | `"1Gi"` | size limit of the emptyDir backing /tmp, where config repositories are cloned and plans are rendered |
| controlplane.tolerations | list | `[]` |  |
| controlplane.topologySpreadConstraints | list | `[]` |  |
| controlplane.volumeMounts | list | `[]` | additional volume mounts |
| controlplane.volumes | list | `[]` | additional volumes |
| database | object | `{"existingSecret":"","existingSecretKey":"DATABASE_URL","maxConns":"","url":""}` | postgresql. one of `cnpg.enabled`, `database.url` or `database.existingSecret` is required; the controlplane refuses to start without a database. |
| database.existingSecret | string | `""` | read the connection string from an existing secret instead |
| database.existingSecretKey | string | `"DATABASE_URL"` | key in that secret holding the connection string |
| database.maxConns | string | `""` | maximum pooled connections. empty uses the binary's own default. |
| database.url | string | `""` | full connection string, e.g. postgres://konfig:secret@postgres:5432/konfig?sslmode=require |
| fullnameOverride | string | `""` |  |
| imagePullSecrets | list | `[]` |  |
| messagebus | object | `{"auth":{"agentPassword":"","controlplanePassword":"","existingSecret":"","secretName":"konfig-messagebus"},"url":""}` | the message bus. the controlplane and every agent connect to it, with the two credentials below; see `nats` for the server itself. |
| messagebus.auth.agentPassword | string | `""` | password every agent presents. required when `nats.enabled`; this is the value that goes in each host's `/etc/konfig/agent.env` NATS_URL. |
| messagebus.auth.controlplanePassword | string | `""` | password the controlplane presents. required when `nats.enabled`. |
| messagebus.auth.existingSecret | string | `""` | use a secret you manage instead. it must carry `controlplane-password` and `agent-password`, and `nats.container.env` must name it. |
| messagebus.auth.secretName | string | `"konfig-messagebus"` | name of the secret holding the two passwords. deliberately a literal name rather than one derived from the release: the nats subchart has to name the same secret under `nats.container.env`, and helm cannot template a subchart's values. running two konfig releases in one namespace means changing this and both `secretKeyRef.name`s below. |
| messagebus.url | string | `""` | nats url the controlplane dials. required when `nats.enabled` is false. ignored otherwise, because the url is built from the bundled release and the controlplane password. |
| nameOverride | string | `""` |  |
| nats | object | `{"config":{"cluster":{"enabled":false},"jetstream":{"enabled":true,"fileStore":{"pvc":{"size":"10Gi","storageClassName":""}}},"merge":{"authorization":{"users":[{"password":"<< $NATS_CONTROLPLANE_PASSWORD >>","permissions":{"publish":{"allow":[">"]},"subscribe":{"allow":[">"]}},"user":"controlplane"},{"password":"<< $NATS_AGENT_PASSWORD >>","permissions":{"publish":{"allow":["controlplane","artifacts.get","agents.enrol","_INBOX.>"]},"subscribe":{"allow":["agent.>","_INBOX.>"]}},"user":"agent"}]}}},"container":{"env":{"NATS_AGENT_PASSWORD":{"valueFrom":{"secretKeyRef":{"key":"agent-password","name":"konfig-messagebus"}}},"NATS_CONTROLPLANE_PASSWORD":{"valueFrom":{"secretKeyRef":{"key":"controlplane-password","name":"konfig-messagebus"}}}}},"enabled":true}` | the upstream nats chart (https://github.com/nats-io/k8s). everything under this key is its own values; only the authorization block is konfig's opinion.  agents run outside the cluster, so they need to reach this service: expose it with `nats.service.merge` (a LoadBalancer or a NodePort), or put it behind whatever already fronts the cluster. |
| nats.config.jetstream | object | `{"enabled":true,"fileStore":{"pvc":{"size":"10Gi","storageClassName":""}}}` | jetstream backs the events stream, which is what gives the events page replay and history. without it events are live-only. |
| nats.config.merge | object | `{"authorization":{"users":[{"password":"<< $NATS_CONTROLPLANE_PASSWORD >>","permissions":{"publish":{"allow":[">"]},"subscribe":{"allow":[">"]}},"user":"controlplane"},{"password":"<< $NATS_AGENT_PASSWORD >>","permissions":{"publish":{"allow":["controlplane","artifacts.get","agents.enrol","_INBOX.>"]},"subscribe":{"allow":["agent.>","_INBOX.>"]}},"user":"agent"}]}}` | subject permissions, the part konfig cares about. a single shared token would let any managed host read every organisation's events, publish desired state (arbitrary config, therefore arbitrary code) to any other host, and forge the events reactors act on. two users with the permissions below close all three.  what this does not close: one agent can still subscribe to another agent's subject, because every agent presents the same credential. closing that needs a credential per host (nats auth callout), which konfig does not mint yet.  `<< $VAR >>` is the nats chart's syntax for an unquoted value, so the server expands the environment variables set under `container.env`. |
| nats.container.env | object | `{"NATS_AGENT_PASSWORD":{"valueFrom":{"secretKeyRef":{"key":"agent-password","name":"konfig-messagebus"}}},"NATS_CONTROLPLANE_PASSWORD":{"valueFrom":{"secretKeyRef":{"key":"controlplane-password","name":"konfig-messagebus"}}}}` | the passwords the authorization block above expands. the secret named here is the one `messagebus.auth.secretName` creates. |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automount | bool | `false` | neither component talks to the kubernetes api, so the token is not mounted |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| urls | object | `{"api":"","console":"","extraOrigins":[]}` | how this deployment is reached from a browser. the console fetches the api from `api`, and the controlplane refuses cors from anywhere other than `console`, so both have to be the urls a browser actually uses. left empty they are derived from the ingress or httproute of each component, falling back to the localhost ports `kubectl port-forward` gives you. |
| urls.api | string | `""` | browser-facing url of the controlplane api (becomes the console's apiUrl) |
| urls.console | string | `""` | browser-facing url of the console (becomes FRONTEND_URL) |
| urls.extraOrigins | list | `[]` | additional cors origins the controlplane accepts (KONFIG_EXTRA_ORIGINS) |

----------------------------------------------

