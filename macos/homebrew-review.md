# Homebrew to mise review

Audit date: 2026-10-25, macOS arm64. Reviewed 293 installed formulae
and 16 installed casks, including transitive libraries.

71 formulae and 4 CLI casks have validated mise replacements.
45 native formulae, 177 dependency formulae, and 12 desktop casks
remain eligible for Homebrew management. A migrated formula may also remain
installed when a retained Homebrew package depends on it.

Final inventory: **224 formulae and 12 casks**. Removed 69 redundant formulae
and all 4 CLI casks. Homebrew retains `protobuf` for `onnx` and `pytorch`, and
`python@3.15` for `nmap` and `watchman`; mise provides their interactive CLI
versions. All 45 native formulae and 177 other dependency formulae remain.

During the first removal attempt, Homebrew implicitly autoremoved 17 unused
dependency formulae. They were restored with their original request metadata.
Both migration and update now set `HOMEBREW_NO_AUTOREMOVE=1`.

Verified 75 configured mise tools (77 runtime/tool versions), all replacement
probes, 12 post-removal command checks, and `brew missing` with no missing
dependencies. A fresh login shell resolves the migrated commands through mise.

The replacement list is executable data in [mise-migrations.tsv](mise-migrations.tsv).
The migration probes each executable before removing anything. Removal uses
Homebrew's dependency checks, saves a restore Brewfile and version inventory,
and does not run autoremove, change database data, or remove desktop apps.

## Runtimes and compatibility

Node keeps the existing `lts` request. .NET keeps both 10 and 8, Python keeps
3.15 and 3.14, Ruby stays on 4.0, Yarn stays on 1.22, and Terraform stays on
1.5. Project configs can select other versions. Bun is also managed by mise;
existing Bun globals remain under `~/.bun`.

The old `obsidian-cli` executable is retained with the upstream 0.2 release
range; newer releases rename it to `notesmd-cli`. The Homebrew API returned
the renamed formula even though the installed keg was still `obsidian-cli`.
Memo installs directly from `antoniorodr/memo`, since the PyPI package named
`memo` is unrelated. Whisper uses its upstream repository and a private Python
3.14 environment. The legacy LocalStack CLI is preserved; its upstream now
recommends a separate migration to lstk.

## Formulae with mise replacements

| Homebrew formula       | mise tool                        |
| ---------------------- | -------------------------------- |
| `act`                  | `act`                            |
| `aws-elasticbeanstalk` | `awsebcli`                       |
| `aws-sam-cli`          | `aws-sam-cli`                    |
| `awscli`               | `awscli`                         |
| `bat`                  | `bat`                            |
| `cloudflared`          | `cloudflared`                    |
| `cmake`                | `cmake`                          |
| `cocoapods`            | `cocoapods`                      |
| `deno`                 | `deno`                           |
| `diff-so-fancy`        | `npm:diff-so-fancy`              |
| `direnv`               | `direnv`                         |
| `doctl`                | `doctl`                          |
| `dotnet`               | `dotnet@10`                      |
| `dotnet@8`             | `dotnet@8`                       |
| `eza`                  | `cargo:eza`                      |
| `fastfetch`            | `fastfetch`                      |
| `fd`                   | `fd`                             |
| `fzf`                  | `fzf`                            |
| `gh`                   | `gh`                             |
| `gifgrep`              | `github:steipete/gifgrep`        |
| `git-delta`            | `delta`                          |
| `go`                   | `go`                             |
| `gogcli`               | `github:openclaw/gogcli`         |
| `goplaces`             | `github:openclaw/goplaces`       |
| `graphite`             | `npm:@withgraphite/graphite-cli` |
| `helix`                | `helix`                          |
| `himalaya`             | `himalaya`                       |
| `imsg`                 | `github:openclaw/imsg`           |
| `jq`                   | `jq`                             |
| `lazygit`              | `lazygit`                        |
| `localstack-cli`       | `localstack`                     |
| `memo`                 | `pypi:antoniorodr/memo`          |
| `neovim`               | `neovim`                         |
| `node`                 | `node`                           |
| `obsidian-cli`         | `github:Yakitrak/notesmd-cli`    |
| `openai-whisper`       | `pypi:openai/whisper`            |
| `openjdk`              | `java`                           |
| `ordercli`             | `github:steipete/ordercli`       |
| `peekaboo`             | `github:openclaw/Peekaboo`       |
| `pipx`                 | `pipx`                           |
| `pnpm`                 | `pnpm`                           |
| `powershell`           | `powershell`                     |
| `protobuf`             | `protobuf`                       |
| `pscale`               | `aqua:planetscale/cli`           |
| `python@3.14`          | `python@3.14`                    |
| `python@3.15`          | `python@3.15`                    |
| `ranger`               | `pypi:ranger-fm`                 |
| `rclone`               | `rclone`                         |
| `remindctl`            | `github:openclaw/remindctl`      |
| `ripgrep`              | `ripgrep`                        |
| `ruby`                 | `ruby`                           |
| `ruff`                 | `ruff`                           |
| `sbt`                  | `sbt`                            |
| `scala`                | `scala`                          |
| `scala-cli`            | `scala-cli`                      |
| `sentry-cli`           | `sentry-cli`                     |
| `shellcheck`           | `shellcheck`                     |
| `sst`                  | `sst`                            |
| `starship`             | `starship`                       |
| `stripe`               | `stripe`                         |
| `summarize`            | `npm:@steipete/summarize`        |
| `supabase`             | `supabase`                       |
| `terraform`            | `terraform`                      |
| `tmuxinator`           | `gem:tmuxinator`                 |
| `tree-sitter-cli`      | `tree-sitter`                    |
| `uv`                   | `uv`                             |
| `xcodegen`             | `xcodegen`                       |
| `yarn`                 | `npm:yarn`                       |
| `yq`                   | `yq`                             |
| `yt-dlp`               | `yt-dlp`                         |
| `zoxide`               | `zoxide`                         |

## CLI casks with mise replacements

| Homebrew cask   | mise tool                  |
| --------------- | -------------------------- |
| `1password-cli` | `1password-cli`            |
| `gcloud-cli`    | `gcloud`                   |
| `goplaces`      | `github:openclaw/goplaces` |
| `xurl`          | `github:xdevplatform/xurl` |

The formula and cask copies of goplaces both resolve to the same mise tool.

## Native Homebrew packages retained

These choices preserve the existing native packages and integrations. Some
could be rebuilt with custom recipes or installed into a conda environment;
that would require separate compatibility and linkage validation.

| Packages                                                                                              | Reason                                                                                                                                                                                                         |
| ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mise`, `bash`, `git`                                                                                 | mise updates through Homebrew; retain the native shell and full Git distribution.                                                                                                                              |
| `gcc`, `llvm`, `llvm@17`, `clang-format`, `pkgconf`                                                   | Retain compiler libraries, headers, versioned LLVM and existing linkage.                                                                                                                                       |
| `btop`, `htop`, `tmux`, `tree`, `wget`, `coreutils`, `flock`, `multitime`, `fping`, `nmap`, `sshpass` | Preserve the installed native implementations. btop has no upstream macOS release asset; mise coreutils is a different implementation. The available upstream tmux binary is older than the installed version. |
| `pam-reattach`, `create-dmg`, `terminal-notifier`, `watchman`                                         | PAM, app bundles, system frameworks, and native filesystem integration.                                                                                                                                        |
| `wireguard-tools`, `wireguard-go`, `freerdp`, `microk8s`                                              | Preserve VPN helpers, framework/library linkage and virtualization integration.                                                                                                                                |
| `postgresql@17`, `postgresql@18`, `mysql-client`, `libpq`                                             | Preserve database service paths, data locations and client headers. No database commands or migrations were run.                                                                                               |
| `ffmpeg`, `sox`, `graphviz`, `espeak-ng`, `portaudio`                                                 | Preserve the existing native codec, graph rendering and audio library stack.                                                                                                                                   |
| `gdbm`, `libev`, `mvfst`                                                                              | Shared native dependencies, not independently versioned developer CLIs.                                                                                                                                        |
| `rbenv`, `rbenv-default-gems`, `rbenv-gemset`                                                         | Preserve legacy project gemset support; mise owns the default Ruby, CocoaPods and tmuxinator.                                                                                                                  |
| `gdrive`                                                                                              | Upstream publishes only an Intel Mac binary; preserve the native Homebrew build.                                                                                                                               |
| `livekit`                                                                                             | Upstream has no Mac release asset; go install rejects its replace directives. Preserve the native Homebrew build.                                                                                              |
| `speedtest`                                                                                           | Keep the installed vendor CLI and license behavior; speedtest-cli is a different tool.                                                                                                                         |

The Brewfile also retains previously configured packages/apps that were not
installed during this audit, including Ollama. MicroK8s and SST were omitted by the Homebrew API inventory; both were cross-checked against the original version list. Ollama remains a
Homebrew service choice. No `brew bundle cleanup` or Nix activation was run.

## Desktop casks retained

`caffeine`, `dropbox`, `flux-app`, `ghostty`, `mactex`, `multipass`, `orbstack`, `raycast`, `stats`, `codexbar`, `vlc`, `zed`.

These remain in Homebrew because they install desktop apps, privileged
components, or the MacTeX distribution.

## Dependency formulae reviewed

The following 177 formulae form the existing native dependency and media
stack. They are retained rather than uninstalled or independently rehomed.
Homebrew continues managing dependency versions needed by the remaining tools.
This list includes pre-existing unused dependencies; no broad cleanup was run.

```text
abseil
ada-url
aom
autoconf
aws-c-auth
aws-c-cal
aws-c-common
aws-c-compression
aws-c-event-stream
aws-c-http
aws-c-io
aws-c-mqtt
aws-c-s3
aws-c-sdkutils
aws-checksums
boost
brotli
c-ares
ca-certificates
cairo
certifi
cffi
cryptography
dav1d
double-conversion
edencommon
eigen
fb303
fbthrift
fizz
flac
fmt
folly
fontconfig
freetype
fribidi
gd
gdk-pixbuf
gettext
gflags
ghostscript
giflib
glib
glog
gmp
graphite2
gts
harfbuzz
hdrhistogram_c
highway
icu4c@78
icu4c@79
imath
isl
jansson
jasper
jbig2dec
jemalloc
jpeg-turbo
jpeg-xl
json-c
krb5
lame
leptonica
libarchive
libavif
libb2
libcbor
libdatrie
libdeflate
libevent
libffi
libfido2
libgit2
libidn
libidn2
liblinear
libmpc
libnghttp2
libogg
libomp
libpng
libpsl
librsvg
libsndfile
libsodium
libssh2
libthai
libtiff
libtool
libunistring
libusb
libuv
libvmaf
libvorbis
libvpx
libx11
libxau
libxcb
libxcursor
libxdmcp
libxext
libxfixes
libxi
libxinerama
libxrandr
libxrender
libxv
libyaml
little-cms2
llhttp
llvm@22
lpeg
lua
luajit
luv
lz4
lzo
m4
mad
merve
mpdecimal
mpfr
mpg123
nbytes
ncurses
netpbm
numpy
oniguruma
onnx
openblas
openexr
openjpeg
openjph
openssl@3
openssl@4
opus
opusfile
pango
pcaudiolib
pcre2
pixman
pybind11
pycparser
pydantic
pytorch
readline
rpds-py
ruby-build
s2n
sdl2-compat
sdl3
sdl3_ttf
simdjson
simdutf
sleef
snappy
sqlite
svt-av1
tesseract
tmuxinator-completion
tree-sitter
unibilium
uriparser
utf8proc
uvwasi
wangle
webp
x264
x265
xorgproto
xxhash
xz
yyjson
z3
zlib-ng-compat
zstd
```

## mise tracking repair

Automatic reshim was blocked reading an archived project config under
`~/Documents/Codex/2026-10-07/task/internal-admin-release/mise.toml`. Its tracking
symlink was moved from `~/.local/state/mise/tracked-configs/ccd82c7f7ec26fcf`
to `~/.local/state/mise/archived-tracked-configs/ccd82c7f7ec26fcf`. The project
file was not modified. Setup and reshim completed after this change.

## Reference behavior

[mise upgrade](https://mise.jdx.dev/cli/upgrade.html) supports global-only upgrades
and explicit confirmation. [mise's PyPI backend](https://mise.jdx.dev/dev-tools/backends/pypi.html)
supports upstream GitHub packages and per-tool Python selection.
[Homebrew's manual](https://docs.brew.sh/Manpage) documents `--yes` and the
remaining formula/cask update behavior. Local installed CLI help and executable
probes were checked as part of this migration.
