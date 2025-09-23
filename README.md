# kaniko-build/build

Repository to build OCI images of Kaniko's fork

* [chainguard-dev fork of kaniko](https://github.com/chainguard-dev/kaniko/)
* [mzihlmann fork of kaniko](https://github.com/mzihlmann/kaniko)

Actions are taken from the original build process with few changes to adapt to ghcr and monkey patch version in `Makefile`.

Results are available at:

* chainguard-dev/kaniko
  * Warmer: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fchainguard-dev-kaniko%2Fwarmer>
  * Executor: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fchainguard-dev-kaniko%2Fexecutor>
* mzihlmann/kaniko
  * Warmer: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fmzihlmann-kaniko%2Fwarmer>
  * Executor: <https://github.com/kaniko-build/builder/pkgs/container/dist%2Fchainguard-dev-kaniko%2Fexecutor>
