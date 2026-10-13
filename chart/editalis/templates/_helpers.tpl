{{- define "editalis.labels" -}}
app.kubernetes.io/name: editalis
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "editalis.selector" -}}
app.kubernetes.io/name: editalis
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "editalis.image" -}}
{{ .Values.image.repository }}:{{ .Values.image.tag }}
{{- end }}

{{/* Same hardening for every container the chart runs. */}}
{{- define "editalis.containerSecurity" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}

{{- define "editalis.podSecurity" -}}
runAsNonRoot: true
runAsUser: 10001
runAsGroup: 10001
fsGroup: 10001
seccompProfile:
  type: RuntimeDefault
{{- end }}
