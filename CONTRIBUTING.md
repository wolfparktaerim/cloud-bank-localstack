# Contributing Guide

## Branch Strategy

```
main        ← protected, final submissions only
develop     ← integration branch, all features merge here
feature/*   ← your daily work
fix/*       ← bug fixes
docs/*      ← documentation only changes
```

## Step-by-Step: Opening a PR

1. **Always branch from `develop`** (never from `main`)
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Commit messages** — use conventional commits:
   ```
   feat: add S3 bucket for KYC documents
   fix: correct IAM policy for Lambda execution
   docs: update architecture diagram
   chore: update terraform provider version
   ```

3. **Push and open PR**
   ```bash
   git push origin feature/your-feature-name
   # Go to GitHub → New Pull Request → base: develop
   ```

4. **PR checklist** (see PR template):
   - [ ] `terraform validate` passes
   - [ ] `terraform fmt` applied
   - [ ] Tests added/updated
   - [ ] README updated if needed
   - [ ] At least 1 team member reviewed

5. **Never merge your own PR** — always get a review.

## Module Ownership

To avoid conflicts, each member owns specific folders:

| Member | Owns |
|--------|------|
| Member 1 | `terraform/modules/networking/`, `terraform/modules/iam/`, `terraform/providers.tf` |
| Member 2 | `terraform/modules/compute/`, `terraform/modules/api_gateway/` |
| Member 3 | `terraform/modules/database/`, `terraform/modules/storage/` |
| Member 4 | `terraform/modules/messaging/`, `terraform/modules/monitoring/` |
| Member 5 | `services/`, `tests/`, `.github/workflows/` |

If you need to change another member's module, **talk to them first** and co-author the commit.

## Code Style

**Terraform:**
- Always run `terraform fmt` before committing
- Use `snake_case` for resource names
- Add a comment block above each resource explaining its purpose
- Use variables — never hardcode values

**Python:**
- Follow PEP8
- Add docstrings to all functions
- Use type hints

## Resolving Merge Conflicts

```bash
git checkout develop
git pull origin develop
git checkout feature/your-branch
git rebase develop
# Fix conflicts in your editor
git add .
git rebase --continue
git push origin feature/your-branch --force-with-lease
```
