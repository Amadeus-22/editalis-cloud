.PHONY: check fmt validate scan chart manifests rules drill demo demo-down

CRDS := https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json
KUBE := 1.31.0

## Everything the CI pipeline runs, in the same order.
check: fmt validate scan chart manifests

fmt:
	terraform -chdir=terraform fmt -check -recursive

validate:
	terraform -chdir=terraform/envs/dev init -backend=false -input=false > /dev/null
	terraform -chdir=terraform/envs/dev validate

scan:
	checkov -d terraform --config-file .checkov.yaml --quiet --compact
	trivy config --quiet --severity HIGH,CRITICAL --ignorefile .trivyignore \
	  --skip-dirs terraform/envs/dev/.terraform --exit-code 1 terraform

chart:
	helm lint chart/editalis
	helm template demo chart/editalis --namespace editalis | kubeconform -strict -summary -kubernetes-version $(KUBE)

manifests:
	kubeconform -strict -summary -kubernetes-version $(KUBE) -schema-location default \
	  -schema-location '$(CRDS)' gitops monitoring/rules.yaml monitoring/dashboard.yaml

## Backup and restore drill against a throwaway PostgreSQL (needs Docker).
drill:
	./scripts/restore-drill.sh

## Local cluster with Argo CD deploying the chart (needs kind, ~2 GB of free memory).
demo:
	./scripts/demo-up.sh

demo-down:
	kind delete cluster --name editalis-lab
