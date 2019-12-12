{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "speechlab.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "speechlab.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "speechlab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Define name for master and worker.
*/}}
{{- define "speechlab.master.name" -}}
{{- printf "%s-%s" .Release.Name "master" | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "speechlab.worker.name" -}}
{{- printf "%s-%s" .Release.Name "worker" | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "speechlab.master.command" -}}
{{- join "," .Values.commands.master }}
{{- end -}}

{{- define "speechlab.worker.command" -}}
{{- $pre := join "," .Values.commands.worker.pre -}}
{{- $post := join "," .Values.commands.worker.post -}}
{{- printf "%s ,%s-%s, %s" $pre .Release.Name "master" $post -}}
{{- end -}}