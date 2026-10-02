# GitHub setup for hciengr

Prepared destination: https://github.com/hciengr/bc250-vcn-community

1. Sign in as hciengr and create an **empty private** repository named
   `bc250-vcn-community`. Do not initialize it with a README, license or gitignore;
   the prepared project already contains its own files and attribution notices.
2. Connect this workstation through GitHub's authentication flow. No password or
   token needs to be pasted into a chat. The verified portable GitHub CLI is installed at `../../tools/github-cli/bin/gh`.
3. From this directory, create an initial local commit using your configured Git
   identity and push main to the prepared origin. Review the file inventory first;
   `_site`, `upstream/cache.git` and synchronization locks are ignored.
4. Invite independent reviewers. Keep `trusted_reviewers` empty until their
   accountable usernames and reproduction responsibilities are agreed.
5. Configure the required branch protections in VERIFICATION.md. CODEOWNERS routes
   changes to hciengr, but code ownership alone does not verify findings. A reviewer
   must be independent of a finding's author and accountable human coordinator.
6. Keep public_launch_ready false and Pages disabled while reviewing setup. The
   Pages workflow deliberately fails its launch gate during this period. Make the
   repository public and enable hosting only after verifying the protections and
   contribution process. Available private-repository protection/Pages features
   depend on the GitHub plan; inspect the actual account settings before relying
   on them.

The configured repository links are a planned destination, not evidence that the
remote repository has been created or that any content has been uploaded.
