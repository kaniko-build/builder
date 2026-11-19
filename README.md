# kaniko-build/build

Repository to build OCI images of Kaniko's fork

* [osscontainertools fork of kaniko](https://github.com/osscontainertools/kaniko)
* [chainguard-forks fork of kaniko](https://github.com/chainguard-forks/kaniko/)

Actions are taken from the original build process with few changes to adapt to ghcr and monkey patch version in `Makefile`.

## Automatic builds

`Build missing releases` runs daily (04:23 UTC) and on demand. For each fork it builds the stable upstream releases newer than the last one published here, oldest first, one at a time (each publish moves `latest`). Platforms are the ones every target-platform base image of the release's `deploy/Dockerfile` provides (`--platform=$BUILDPLATFORM` stages are ignored).

* Same check from a workstation: `./scripts/build-missing.sh` (dry run), `./scripts/build-missing.sh --dispatch` to build. Needs `gh`, `jq` and `docker buildx`.
* GitHub disables the schedule after 60 days without repository activity: re-enable it with `gh workflow enable build-missing.yml`.

Results are available at:


* osscontainertools/kaniko
  * Warmer: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fosscontainertools-kaniko%2Fwarmer>
  * Executor: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fosscontainertools-kaniko%2Fexecutor>

* chainguard-forks/kaniko
  * Warmer: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fchainguard-forks-kaniko%2Fwarmer>
  * Executor: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fchainguard-forks-kaniko%2Fexecutor>


* chainguard-dev/kaniko (retained for history, renamed to chainguard-forks/kaniko)
  * Warmer: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fchainguard-dev-kaniko%2Fwarmer>
  * Executor: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fchainguard-dev-kaniko%2Fexecutor>

* mzihlmann/kaniko (retained for backward compatibility but no longer build)
  * Warmer: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fmzihlmann-kaniko%2Fwarmer>
  * Executor: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fmzihlmann-kaniko%2Fexecutor>
