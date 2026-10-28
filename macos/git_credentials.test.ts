import { afterEach, expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const script = join(import.meta.dir, "git_credentials.sh");
const fixtures: string[] = [];

afterEach(() => {
  for (const path of fixtures.splice(0)) rmSync(path, { recursive: true });
});

function fixture() {
  const home = mkdtempSync(join(tmpdir(), "git credentials-"));
  fixtures.push(home);
  const data = join(home, "mise");
  const shims = join(data, "shims");
  const log = join(home, "helper-calls");
  mkdirSync(shims, { recursive: true });
  writeFileSync(
    join(shims, "gh"),
    `#!/bin/sh
if [ "$*" != "auth git-credential get" ]; then exit 2; fi
printf 'called\\n' >> "$AUTH_LOG"
printf 'username=fixture\\npassword=fixture-token\\n'
`,
    { mode: 0o755 },
  );
  const env = {
    HOME: home,
    PATH: "/usr/bin:/bin:/usr/sbin:/sbin",
    MISE_DATA_DIR: data,
    GIT_CONFIG_GLOBAL: join(home, ".gitconfig"),
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_TERMINAL_PROMPT: "0",
    AUTH_LOG: log,
  };
  function git(args: string[], stdin?: string) {
    return Bun.spawnSync(["/usr/bin/git", ...args], {
      env,
      cwd: home,
      stdin: new TextEncoder().encode(stdin),
    });
  }
  function configure(host: string, helper: string) {
    expect(
      git(["config", "--global", "--add", `credential.https://${host}.helper`, helper]).exitCode,
    ).toBe(0);
  }
  return {
    home,
    shims,
    log,
    git,
    configure,
    repair() {
      return Bun.spawnSync(["/bin/bash", script], { env, cwd: home });
    },
    helpers(host: string) {
      return git([
        "config",
        "--global",
        "--get-all",
        `credential.https://${host}.helper`,
      ]).stdout.toString();
    },
  };
}

test("repairs old GitHub helpers while preserving their reset entries", () => {
  const state = fixture();
  for (const host of ["github.com", "gist.github.com"]) {
    state.configure(host, "");
    state.configure(host, "!/opt/homebrew/bin/gh auth git-credential");
  }
  expect(state.repair().exitCode).toBe(0);
  for (const host of ["github.com", "gist.github.com"]) {
    const helpers = state.helpers(host);
    expect(helpers.startsWith("\n")).toBe(true);
    expect(helpers).not.toContain("/opt/homebrew/bin/gh");
    expect(helpers).toContain("/shims/gh auth git-credential");
  }
});

test("repaired helpers authenticate with a GUI-style PATH and spaces in the home path", () => {
  const state = fixture();
  state.configure("github.com", "");
  state.configure("github.com", "!/usr/local/bin/gh auth git-credential");
  expect(state.repair().exitCode).toBe(0);
  const result = state.git(["credential", "fill"], "protocol=https\nhost=github.com\n\n");
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString()).toContain("username=fixture");
  expect(readFileSync(state.log, "utf8")).toBe("called\n");
});

test("preserves custom helpers and other credential hosts", () => {
  const state = fixture();
  state.configure("github.com", "!custom-helper get");
  state.configure("example.com", "!/opt/homebrew/bin/gh auth git-credential");
  expect(state.repair().exitCode).toBe(0);
  expect(state.helpers("github.com")).toBe("!custom-helper get\n");
  expect(state.helpers("example.com")).toBe("!/opt/homebrew/bin/gh auth git-credential\n");
});

test("repeated repair does not duplicate helper entries", () => {
  const state = fixture();
  state.configure("github.com", "");
  state.configure("github.com", "!/opt/homebrew/bin/gh auth git-credential");
  expect(state.repair().exitCode).toBe(0);
  const first = state.helpers("github.com");
  expect(state.repair().exitCode).toBe(0);
  expect(state.helpers("github.com")).toBe(first);
});

test("missing mise shim leaves the existing helper unchanged and reports failure", () => {
  const state = fixture();
  state.configure("github.com", "!/opt/homebrew/bin/gh auth git-credential");
  rmSync(join(state.shims, "gh"));
  expect(state.repair().exitCode).toBe(1);
  expect(state.helpers("github.com")).toBe("!/opt/homebrew/bin/gh auth git-credential\n");
});
