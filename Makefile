.PHONY: fmt fmt-check init validate lint scan test plan plan-scan plan-guard check demo-fail clean

MODULE := modules/secure-bucket
ENV    := envs/dev

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive -diff

init:
	terraform -chdir=$(MODULE) init -backend=false -input=false
	terraform -chdir=$(ENV) init -backend=false -input=false

validate: init
	terraform -chdir=$(MODULE) validate
	terraform -chdir=$(ENV) validate

lint:
	tflint --init
	tflint --chdir=$(MODULE)
	tflint --chdir=$(ENV)

scan:
	checkov --config-file .checkov.yaml

test: init
	terraform -chdir=$(MODULE) test

plan: init
	terraform -chdir=$(ENV) plan -var offline=true -input=false -out=tfplan

plan-scan: plan
	terraform -chdir=$(ENV) show -json tfplan > $(ENV)/tfplan.json
	checkov -f $(ENV)/tfplan.json --framework terraform_plan --compact --quiet --skip-check CKV_AWS_145

# Fails if the plan would delete or replace anything. Fine for a new lab stack;
# in a real pipeline you would allow this only with explicit approval.
plan-guard: plan-scan
	jq -e '[.resource_changes[] | select(.change.actions | index("delete"))] | length == 0' $(ENV)/tfplan.json

check: fmt-check validate lint scan test plan-guard

demo-fail:
	checkov -d fixtures/insecure-bucket --framework terraform --compact --quiet

clean:
	rm -rf $(MODULE)/.terraform $(ENV)/.terraform $(ENV)/tfplan $(ENV)/tfplan.json
