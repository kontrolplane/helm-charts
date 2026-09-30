{{/*
expand the name of the chart.
*/}}
{{- define "tsui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
create a default fully qualified app name.
*/}}
{{- define "tsui.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
create chart name and version as used by the chart label.
*/}}
{{- define "tsui.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
common labels
*/}}
{{- define "tsui.labels" -}}
helm.sh/chart: {{ include "tsui.chart" . }}
{{ include "tsui.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
selector labels
*/}}
{{- define "tsui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tsui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
