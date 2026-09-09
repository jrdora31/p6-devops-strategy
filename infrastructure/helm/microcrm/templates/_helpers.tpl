{{- define "microcrm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "microcrm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "microcrm.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "microcrm.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/name: {{ include "microcrm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "microcrm.releaseLabels" -}}
microcrm.io/track: {{ .track | quote }}
app.kubernetes.io/version: {{ .version | quote }}
{{- end }}

{{- define "microcrm.image" -}}
{{- if .digest -}}
{{ printf "%s@%s" .repository .digest }}
{{- else -}}
{{ printf "%s:%s" .repository (required "image.tag est obligatoire lorsque image.digest est vide" .tag) }}
{{- end -}}
{{- end }}
