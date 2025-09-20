# DevOps PR Preview  Automation

This repository contains a workflow to **deploy, manage, and clean up preview environments** for pull requests (PRs) using GitHub Actions, Docker, and ngrok. It also manages GitHub Container Registry (GHCR) images for each PR.

---

## 🔹 Project Overview

When working with feature branches or PRs, we often want a **preview environment** to:

- Test the application in isolation
- Share a live URL with team members
- Validate functionality before merging

This workflow automates:

1. Deploying a Docker container for the PR
2. Exposing it via ngrok
3. Cleaning up when the PR is closed
4. Deleting the corresponding container image from GHCR
5. Commenting on the PR to confirm cleanup

---

## 🔹 Workflow

### 1️⃣ PR Deployment

- GitHub Action builds and pushes a Docker image tagged with the PR number (`pr-<number>`)
- Container runs on a self-hosted runner
- ngrok exposes the container to a temporary public URL

### 2️⃣ PR Cleanup

- Triggered automatically when a PR is closed or manually via workflow dispatch
- Stops and removes the PR container
- Deletes the corresponding GHCR image tag
- Adds a comment on the PR confirming cleanup

---

## 🔹 Issues Encountered

1. **Ngrok ERR_NGROK_3200**
   - The public URL often shows `The endpoint is offline`
   - Causes:
     - ngrok not authenticated with an authtoken
     - ngrok process crashes after container starts
     - Temporary ngrok network issues
   - Workarounds:
     - Ensure `ngrok authtoken` is set correctly
     - Confirm the container exposes the correct port
     - Restart ngrok in the workflow if it fails

2. **GitHub Container Registry (GHCR) Permissions**
   - Deleting images requires `write:packages` scope
   - If using the same PAT for commenting on PRs, errors may occur
   - Solution:
     - Use `GHCR_PAT` with `write:packages` for registry operations
     - Use a separate `REPO_COMMENTER_PAT` with `repo` scope to comment on PRs
3. **DuckDNS Errors**
   - Port Forwading/Firewall rules block inbound traffic to the host machine
   - Causes:
     - Firewall rules
     - Router Confiurations
     - Windowns defender systems
4. **Workflow Errors**
   - YAML formatting issues
   - Using `github.event.number` vs `inputs.pr_number`
   - Conditional steps not triggering correctly

5. **Browser Access**
   - Even when the container is healthy, the ngrok URL sometimes returns a minimal HTML page indicating offline status
   - Likely caused by ngrok misrouting or the container not binding correctly to the expected port

---

## 🔹 Tokens and Secrets

| Secret Name       | Purpose                                           | Required Scope                     |
|------------------|-------------------------------------------------|-----------------------------------|
| `GHCR_PAT`        | Add and Delete preview container images from GHCR       | `write:packages`,  |
| `REPO_COMMENTER_PAT` | Post PR comments after cleanup                  | `repo`       |

---

## 🔹 How to Use

1. Set secrets `GHCR_PAT` and `REPO_COMMENTER_PAT` in your repository
2. Create a PR or manually trigger the cleanup workflow
3. Check logs to ensure container is running and ngrok URL is live
4. Confirm the PR comment after cleanup

---

## 🔹 Notes

- This workflow is optimized for **self-hosted runners**
- For ephemeral environments, ngrok free tier may be unreliable
- Separate tokens improve security and prevent permission errors

---

