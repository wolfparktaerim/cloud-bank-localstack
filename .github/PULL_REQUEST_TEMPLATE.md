## What does this PR do?

<!-- Briefly describe the change -->

## Module / Service affected

<!-- e.g. terraform/modules/database, services/auth -->

## Type of change

- [ ] New Terraform module / resource
- [ ] Update existing module
- [ ] New Python mock service
- [ ] Bug fix
- [ ] Tests
- [ ] Documentation

## Checklist

- [ ] I ran `terraform fmt` on all changed `.tf` files
- [ ] I ran `terraform validate` and it passes
- [ ] I added/updated tests for my changes
- [ ] I updated the relevant `README.md` or `docs/` if needed
- [ ] I did **not** commit any real credentials or secrets
- [ ] I have assigned at least one reviewer

## How to test this locally

```bash
# Steps for reviewer to verify this PR works
docker compose up -d
cd terraform && terraform apply -var-file="environments/localstack/terraform.tfvars" -auto-approve
pytest tests/integration/
```

## Screenshots / Output (if applicable)

<!-- Paste terraform plan output, test results, or curl responses -->
