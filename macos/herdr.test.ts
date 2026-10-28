import { afterEach, expect, test } from "bun:test";
import {
  copyFileSync,
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const homes: string[] = [];
afterEach(() => {
  for (const home of homes.splice(0)) rmSync(home, { recursive: true });
});

function fixture() {
  const home = realpathSync(mkdtempSync(join(tmpdir(), "herdr setup-")));
  homes.push(home);
  const project = join(home, "dotfiles");
  const bin = join(home, "bin");
  mkdirSync(join(project, "macos"), { recursive: true });
  mkdirSync(join(project, "herdr"));
  mkdirSync(bin);
  for (const name of ["herdr.sh", "link_config.sh"])
    copyFileSync(join(root, "macos", name), join(project, "macos", name));
  copyFileSync(join(root, "herdr/config.toml"), join(project, "herdr/config.toml"));
  writeFileSync(join(project, "herdr/integrations.txt"), "# integrations\nclaude\ncodex\n");
  const log = join(home, "calls");
  writeFileSync(log, "");
  function fake(name: string, code: string) {
    writeFileSync(join(bin, name), `#!/bin/bash\n${code}\n`, { mode: 0o755 });
  }
  fake(
    "mise",
    'printf "mise %s\\n" "$*" >> "$CALL_LOG"\nif [[ "$*" == *"which --tool herdr@latest herdr" ]]; then printf "%s/herdr\\n" "$FAKE_BIN"; fi',
  );
  fake(
    "herdr",
    `
printf 'herdr %s\\n' "$*" >> "$CALL_LOG"
printf '%s\\0' "$@" >> "$HOME/herdr-args"
case "$1 $2" in
  "config check") [[ "\${FAIL_CONFIG:-}" != 1 ]] || exit 9;;
  "integration install")
    [[ "$3" != "\${FAIL_INTEGRATION:-}" ]] || exit 8
    if [[ "$3" == "\${MISSING_AGENT:-}" ]]; then
      echo "$3 directory not found at $HOME/.$3. install $3 first" >&2
      exit 1
    fi;;
  "workspace get") printf '%s' "$WORKSPACE_REPLY";;
  "worktree create")
    if [[ " $* " == *" --workspace "* && " $* " == *" --cwd "* ]]; then echo "workspace and cwd are mutually exclusive" >&2; exit 2; fi
    if [[ -n "\${FAIL_CREATE:-}" ]]; then echo "simulated worktree creation error" >&2; exit 8; fi;;
  "worktree remove") if [[ -n "\${DIRTY_WORKTREE:-}" ]]; then echo dirty_worktree_requires_force >&2; exit 1; fi;;
esac
`,
  );
  const env: Record<string, string> = {
    HOME: home,
    PATH: `${bin}:/usr/bin:/bin`,
    CALL_LOG: log,
    FAKE_BIN: bin,
    HERDR_ACTIVE_WORKSPACE_ID: "workspace-fixture",
    WORKSPACE_REPLY: '{"result":{"workspace":{"worktree":{"is_linked_worktree":true}}}}',
  };
  return {
    home,
    project,
    env,
    log,
    fake,
    run() {
      const result = Bun.spawnSync(["/bin/bash", join(project, "macos/herdr.sh")], {
        env,
        cwd: home,
      });
      return {
        status: result.exitCode,
        output: result.stdout.toString() + result.stderr.toString(),
        calls: readFileSync(log, "utf8"),
      };
    },
    closeWorkspace() {
      const config = Bun.TOML.parse(readFileSync(join(project, "herdr/config.toml"), "utf8")) as {
        keys: { command: { key: string; command: string }[] };
      };
      const command = config.keys.command.find(
        (binding) => binding.key === "prefix+shift+k",
      )!.command;
      const result = Bun.spawnSync(["/bin/sh", "-c", command], { env, cwd: home });
      return { status: result.exitCode, calls: readFileSync(log, "utf8") };
    },
    createWorktree(input = "feature/new-worktree\n") {
      const config = Bun.TOML.parse(readFileSync(join(project, "herdr/config.toml"), "utf8")) as {
        keys: { command: { key: string; command: string }[] };
      };
      const command = config.keys.command.find(
        (binding) => binding.key === "prefix+shift+w",
      )!.command;
      const result = Bun.spawnSync(["/bin/sh", "-c", command], {
        env,
        cwd: home,
        stdin: Buffer.from(input),
      });
      return {
        status: result.exitCode,
        output: result.stdout.toString() + result.stderr.toString(),
        calls: readFileSync(log, "utf8"),
      };
    },
  };
}

test("Herdr setup preserves runtime state and backs up the existing config", () => {
  const state = fixture();
  const directory = join(state.home, ".config/herdr");
  mkdirSync(directory, { recursive: true });
  writeFileSync(join(directory, "config.toml"), "onboarding = true\n");
  writeFileSync(join(directory, "session.json"), "private session state");
  const result = state.run();
  expect(result.status).toBe(0);
  expect(realpathSync(join(directory, "config.toml"))).toBe(
    join(state.project, "herdr/config.toml"),
  );
  expect(readFileSync(join(directory, "session.json"), "utf8")).toBe("private session state");
  const backup = readdirSync(directory).find((name) => name.startsWith("config.toml.backup."));
  expect(backup).toBeDefined();
  expect(readFileSync(join(directory, backup!, "original"), "utf8")).toBe("onboarding = true\n");
  expect(result.calls).toContain("mise use --global --yes herdr@latest");
  expect(result.calls).toContain("herdr integration install claude");
  expect(result.calls).toContain("herdr integration install codex");
  expect(result.calls).not.toContain("herdr server");
});

test("Herdr setup honors config/profile overrides and can be repeated", () => {
  const state = fixture();
  state.env.HERDR_CONFIG_PATH = join(state.home, "custom config/herdr.toml");
  state.env.ZDOTDIR = join(state.home, "zsh config");
  expect(state.run().status).toBe(0);
  expect(state.run().status).toBe(0);
  expect(realpathSync(state.env.HERDR_CONFIG_PATH)).toBe(join(state.project, "herdr/config.toml"));
  expect(
    readFileSync(join(state.env.ZDOTDIR, ".zshrc"), "utf8").match(/# Herdr completions/g),
  ).toHaveLength(1);
  expect(existsSync(join(state.home, ".zshrc"))).toBe(false);
});

test("invalid Herdr config cannot replace a working config or install integrations", () => {
  const state = fixture();
  const directory = join(state.home, ".config/herdr");
  mkdirSync(directory, { recursive: true });
  writeFileSync(join(directory, "config.toml"), "original config\n");
  state.env.FAIL_CONFIG = "1";
  const result = state.run();
  expect(result.status).toBe(9);
  expect(readFileSync(join(directory, "config.toml"), "utf8")).toBe("original config\n");
  expect(result.calls).not.toContain("integration install");
});

test("failed Herdr integrations are reported while independent integrations continue", () => {
  const state = fixture();
  state.env.FAIL_INTEGRATION = "claude";
  const result = state.run();
  expect(result.status).toBe(1);
  expect(result.output).toContain("claude");
  expect(result.calls).toContain("herdr integration install codex");
});

test("Herdr setup skips agents that have not been installed yet", () => {
  const state = fixture();
  state.env.MISSING_AGENT = "claude";
  const result = state.run();
  expect(result.status).toBe(0);
  expect(result.output).toContain("Skipping claude");
  expect(result.calls).toContain("herdr integration install codex");
});

test("Herdr setup honors XDG_CONFIG_HOME and completions tolerate missing compinit", () => {
  const state = fixture();
  state.env.XDG_CONFIG_HOME = join(state.home, "custom xdg");
  expect(state.run().status).toBe(0);
  expect(realpathSync(join(state.env.XDG_CONFIG_HOME, "herdr/config.toml"))).toBe(
    join(state.project, "herdr/config.toml"),
  );
  const loaded = Bun.spawnSync(["/bin/zsh", "-f", "-c", 'source "$HOME/.zshrc"'], {
    env: state.env,
  });
  expect(loaded.exitCode).toBe(0);
  expect(loaded.stderr.toString()).toBe("");
});

test("the custom close binding leaves dirty worktrees open", () => {
  const state = fixture();
  state.env.DIRTY_WORKTREE = "1";
  const result = state.closeWorkspace();
  expect(result.status).toBe(1);
  expect(result.calls).toContain("herdr worktree remove --workspace workspace-fixture");
  expect(result.calls).not.toContain("workspace close");
  expect(result.calls).not.toContain("--force");
});

test("the custom close binding refuses malformed workspace metadata", () => {
  const state = fixture();
  state.env.WORKSPACE_REPLY = "not JSON";
  const result = state.closeWorkspace();
  expect(result.status).toBe(1);
  expect(result.calls).not.toContain("worktree remove");
  expect(result.calls).not.toContain("workspace close");
});

test("the custom close binding removes clean linked worktrees through Herdr", () => {
  const result = fixture().closeWorkspace();
  expect(result.status).toBe(0);
  expect(result.calls).toContain("herdr worktree remove --workspace workspace-fixture");
  expect(result.calls).not.toContain("workspace close");
  expect(result.calls).not.toContain("--force");
});

function worktreeFixture() {
  const state = fixture();
  function git(...args: string[]) {
    const result = Bun.spawnSync(["/usr/bin/git", ...args], { env: state.env, cwd: state.home });
    if (result.exitCode !== 0) throw new Error(result.stderr.toString());
    return result.stdout.toString().trim();
  }
  const remote = join(state.home, "origin.git");
  const source = join(state.home, "source repo");
  const checkout = join(state.home, "active checkout");
  git("init", "--quiet", "--bare", remote);
  git("init", "--quiet", "--initial-branch=main", source);
  git("-C", source, "config", "user.name", "Fixture");
  git("-C", source, "config", "user.email", "fixture@example.invalid");
  writeFileSync(join(source, "tracked"), "initial\n");
  git("-C", source, "add", "tracked");
  git("-C", source, "commit", "--quiet", "-m", "Initial fixture");
  git("-C", source, "remote", "add", "origin", remote);
  git("-C", source, "push", "--quiet", "origin", "main");
  git("clone", "--quiet", "--branch", "main", remote, checkout);
  writeFileSync(join(source, "tracked"), "latest main\n");
  git("-C", source, "commit", "--quiet", "-am", "Advance fixture main");
  git("-C", source, "push", "--quiet", "origin", "main");
  const latest = git("-C", source, "rev-parse", "HEAD");
  state.fake(
    "git",
    `
printf 'git %s\\n' "$*" >> "$CALL_LOG"
for arg in "$@"; do
  if [[ "$arg" == fetch && -n "\${FAIL_FETCH:-}" ]]; then echo "simulated fetch authentication error" >&2; exit 9; fi
done
exec /usr/bin/git "$@"
`,
  );
  state.env.HERDR_ACTIVE_PANE_CWD = checkout;
  state.env.HERDR_BIN_PATH = join(state.home, "bin/herdr");
  return { ...state, git, checkout, latest };
}

test("the new-worktree popup uses Herdr's absolute binary and the freshly fetched main commit", () => {
  const state = worktreeFixture();
  const gitOnly = join(state.home, "git only");
  mkdirSync(gitOnly);
  copyFileSync(join(state.home, "bin/git"), join(gitOnly, "git"));
  state.env.PATH = `${gitOnly}:/usr/bin:/bin`;
  mkdirSync(join(state.checkout, "nested"));
  state.env.HERDR_ACTIVE_PANE_CWD = join(state.checkout, "nested");
  state.git(
    "-C",
    state.checkout,
    "config",
    "remote.origin.fetch",
    "+refs/heads/other:refs/remotes/origin/other",
  );
  const result = state.createWorktree();
  expect(result.status).toBe(0);
  expect(result.output).not.toContain("command not found");
  expect(state.git("-C", state.checkout, "rev-parse", "refs/remotes/origin/main")).toBe(
    state.latest,
  );
  expect(readFileSync(join(state.home, "herdr-args"), "utf8").split("\0")).toEqual([
    "worktree",
    "create",
    "--cwd",
    state.checkout,
    "--branch",
    "feature/new-worktree",
    "--base",
    state.latest,
    "--focus",
    "",
  ]);
});

test.each(["\n", ""])(
  "canceling the new-worktree popup does not fetch or create anything (%j)",
  (input) => {
    const state = worktreeFixture();
    const result = state.createWorktree(input);
    expect(result.status).toBe(0);
    expect(result.calls).not.toContain(" fetch ");
    expect(result.calls).not.toContain("herdr worktree create");
  },
);

test.each(["--orphan", "bad name", "@{-1}"])(
  "invalid new-worktree branch %j is rejected before fetching",
  (branch) => {
    const state = worktreeFixture();
    const result = state.createWorktree(`${branch}\n\n`);
    expect(result.status).toBe(1);
    expect(result.output).toContain("Invalid branch name");
    expect(result.calls).not.toContain(" fetch ");
    expect(result.calls).not.toContain("herdr worktree create");
  },
);

test("the new-worktree popup refuses existing branches rather than silently using an old base", () => {
  const state = worktreeFixture();
  const result = state.createWorktree("main\n\n");
  expect(result.status).toBe(1);
  expect(result.output).toContain("already exists");
  expect(result.calls).not.toContain(" fetch ");
  expect(result.calls).not.toContain("herdr worktree create");
});

test("a failed main fetch cannot create a worktree from a stale main", () => {
  const state = worktreeFixture();
  state.env.FAIL_FETCH = "1";
  const result = state.createWorktree();
  expect(result.status).toBe(1);
  expect(result.output).toContain("simulated fetch authentication error");
  expect(result.calls).not.toContain("herdr worktree create");
});

test("the new-worktree popup keeps Herdr's creation error visible", () => {
  const state = worktreeFixture();
  state.env.FAIL_CREATE = "1";
  const result = state.createWorktree();
  expect(result.status).toBe(1);
  expect(result.output).toContain("simulated worktree creation error");
  expect(result.output).toContain("Press Enter to close");
});

test.each(["HERDR_ACTIVE_WORKSPACE_ID", "HERDR_ACTIVE_PANE_CWD"])(
  "missing %s prevents new-worktree creation",
  (variable) => {
    const state = worktreeFixture();
    delete state.env[variable];
    const result = state.createWorktree();
    expect(result.status).toBe(1);
    expect(result.calls).not.toContain(" fetch ");
    expect(result.calls).not.toContain("herdr worktree create");
  },
);

test("a missing Herdr binary is reported before fetching", () => {
  const state = worktreeFixture();
  state.env.HERDR_BIN_PATH = join(state.home, "missing herdr");
  const result = state.createWorktree();
  expect(result.status).toBe(1);
  expect(result.output).toContain("Herdr executable not found");
  expect(result.calls).not.toContain(" fetch ");
});

test("the new-worktree popup can use PATH when HERDR_BIN_PATH is absent", () => {
  const state = worktreeFixture();
  delete state.env.HERDR_BIN_PATH;
  expect(state.createWorktree().status).toBe(0);
});
