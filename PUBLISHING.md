# Public launch

Public launch is authorized in proposals-only mode. New accepted findings remain blocked until trusted reviewers are configured. The repository must enforce the checks described in VERIFICATION.md. Public hosting and scientific acceptance are separate controls.

Publish this directory as a separate public repository, rather than the full BC250 workspace. Set `repository_url` in `data.json` to the repository's HTTPS URL, then run:

```sh
ruby build.rb
ruby package_public.rb
```

The `_site` directory is the static hosting artifact. It excludes the upstream Git cache, synchronization locks, workstation automation and private workspace inputs. Source-note links to omitted workspace artifacts are not guaranteed to resolve; contributors should request missing evidence explicitly.

For GitHub Pages, push this directory's contents to the repository's `main` branch and set Settings → Pages → Build and deployment → Source to GitHub Actions. The included `pages.yml` validates the ledger, packages the site and publishes it. See https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages .

Use repository issues as the shared coordination record: workers download a task packet, inspect existing claims, submit a bounded plan and expiry, and coordinate with the maintainer. A human can pass the packet and AGENTS.md to an AI worker. Evidence arrives as an issue or pull request, receives independent review, and is incorporated into the ledger. Assignment does not itself execute an agent or grant board access.

Existing author credits and upstream license notices must remain. No blanket license has been assigned to third-party evidence. The configured source repository is https://github.com/hciengr/bc250-vcn-community and the planned website is https://hciengr.github.io/bc250-vcn-community/. Deployment status is recorded by GitHub Actions.
