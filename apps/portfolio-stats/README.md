# portfolio-stats

Daily CronJob that refreshes the numbers on [pablodelarco.com](https://pablodelarco.com): GitHub stars and commits, and the Medium follower count. It runs `scripts/update-stats.mjs` from the [portfolio](https://github.com/pablodelarco/portfolio) repo inside the official Playwright image and pushes `lib/stats.ts` to `main` when a number changed. Every push to `main` deploys the site, so a changed number is live within minutes.

It runs here, from the home IP, because Medium sits behind Cloudflare and answers GitHub-hosted runners with a challenge page. The GitHub Actions job in the portfolio repo still runs every morning as a backup for the GitHub numbers.

## Secret

The job needs a GitHub token with write access to the portfolio repo. Create it once and seal it; the plain token never touches Git.

1. Create a fine-grained personal access token at https://github.com/settings/personal-access-tokens/new with repository access limited to `pablodelarco/portfolio` and the permission `Contents: Read and write`.
2. Seal it from a machine with cluster access and `kubeseal`:

```bash
kubectl -n portfolio-stats create secret generic portfolio-stats-github \
  --from-literal=GITHUB_TOKEN='<token>' --dry-run=client -o yaml \
  | kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller -o yaml \
  > apps/portfolio-stats/manifests/github-token-sealed.yaml
```

3. Commit `github-token-sealed.yaml`. ArgoCD syncs the app and the CronJob can start.

## Run it now

```bash
kubectl -n portfolio-stats create job --from=cronjob/portfolio-stats portfolio-stats-manual
kubectl -n portfolio-stats logs -f job/portfolio-stats-manual
```

## Upgrades

Renovate bumps the image tag. When it does, set `PLAYWRIGHT_VERSION` in `cronjob.yaml` to the same version, because the npm package must match the browsers shipped in the image.
