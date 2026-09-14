{{/*
an ingress for one component. takes a dict of ctx, component and values (the
component's values, which carry `ingress` and `service`).
*/}}
{{- define "konfig.ingress" -}}
{{- $name := include "konfig.componentName" . -}}
{{- $ingress := .values.ingress -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}
  labels:
    {{- include "konfig.labels" . | nindent 4 }}
  {{- with $ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with $ingress.tls }}
  tls:
    {{- range . }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            {{- with .pathType }}
            pathType: {{ . }}
            {{- end }}
            backend:
              service:
                name: {{ $name }}
                port:
                  number: {{ $.values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}

{{/*
an httproute for one component, for gateway api deployments. same dict as
konfig.ingress.
*/}}
{{- define "konfig.httproute" -}}
{{- $name := include "konfig.componentName" . -}}
{{- $route := .values.httpRoute -}}
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ $name }}
  labels:
    {{- include "konfig.labels" . | nindent 4 }}
  {{- with $route.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $route.parentRefs }}
  parentRefs:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $route.hostnames }}
  hostnames:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range $route.rules }}
    {{- with .matches }}
    - matches:
      {{- toYaml . | nindent 8 }}
    {{- end }}
    {{- with .filters }}
      filters:
      {{- toYaml . | nindent 8 }}
    {{- end }}
      backendRefs:
        - name: {{ $name }}
          port: {{ $.values.service.port }}
          weight: 1
    {{- end }}
{{- end }}

{{/*
a service for one component. same dict as konfig.ingress.
*/}}
{{- define "konfig.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "konfig.componentName" . }}
  labels:
    {{- include "konfig.labels" . | nindent 4 }}
  {{- with .values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .values.service.type }}
  ports:
    - port: {{ .values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "konfig.selectorLabels" . | nindent 4 }}
{{- end }}

{{/*
a pod disruption budget for one component. same dict as konfig.ingress.
*/}}
{{- define "konfig.podDisruptionBudget" -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "konfig.componentName" . }}
  labels:
    {{- include "konfig.labels" . | nindent 4 }}
spec:
  {{- with .values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ . }}
  {{- end }}
  {{- if not .values.podDisruptionBudget.maxUnavailable }}
  minAvailable: {{ .values.podDisruptionBudget.minAvailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "konfig.selectorLabels" . | nindent 6 }}
{{- end }}
