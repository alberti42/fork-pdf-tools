# Changelog of epdfinfo

All notable changes to the epdfinfo server are documented in this file.
The changes to the Lisp files of pdf-tools are in `NEWS`.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and epdfinfo adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).
The version describes the protocol spoken by the server, separate from
the version of the pdf-tools package: the major number changes when a
reply changes shape, the minor number when a command is added, the patch
number for a fix.

The version is `EPDFINFO_VERSION` in `server/epdfinfo.h`.
`pdf-info-epdfinfo-version` in `lisp/pdf-info.el` must equal it; a test
checks this.  Change both, and add an entry here, in the commit that
changes the server.

## [Unreleased]

## [1.0.0] - 2026-10-24

The first version with a number.  Builds before it have no `version`
command, and pdf-tools treats them as older than 1.0.0.

### Added

- The `version` command and `epdfinfo --version`, which report
  `EPDFINFO_VERSION`.

### Fixed

- Text that was exactly "." ended a response early, and the rest of the
  response raised "Spurious communication from process epdfinfo".
  A period at the start of a string is now escaped
  ([#376](https://github.com/vedang/pdf-tools/pull/376)).
