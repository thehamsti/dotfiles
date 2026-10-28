import { afterEach, expect, test } from "bun:test";
import { copyFileSync, mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fixtures: string[] = [];

afterEach(() => {
  for (const home of fixtures.splice(0)) rmSync(home, { recursive: true });
});

function fixture(rc: string) {
  const home = realpathSync(mkdtempSync(join(tmpdir(), "shell reload-")));
  fixtures.push(home);
  const macos = join(home, "dotfiles/macos");
  mkdirSync(macos, { recursive: true });
  for (const name of ["aliases.sh", "reload.zsh"]) {
    copyFileSync(join(import.meta.dir, name), join(macos, name));
  }
  writeFileSync(join(home, ".zshrc"), rc);
  return {
    home,
    run(code: string, overrides: Record<string, string> = {}) {
      const result = Bun.spawnSync(
        [
          "/bin/zsh",
          "-f",
          "-c",
          'source "$HOME/dotfiles/macos/aliases.sh"; eval "$1"',
          "reload-test",
          code,
        ],
        {
          env: { HOME: home, PATH: "/usr/bin:/bin", ...overrides },
          cwd: home,
        },
      );
      return {
        status: result.exitCode,
        output: result.stdout.toString(),
        error: result.stderr.toString(),
      };
    },
  };
}

test("reload rejects syntax errors before running any startup commands", () => {
  const state = fixture("RELOAD_VALUE=changed\nif true; then\n");
  const result = state.run(`
RELOAD_VALUE=original
reload
result=$?
print -r -- "status=$result value=$RELOAD_VALUE"
`);
  expect(result.output).toContain("status=1 value=original");
  expect(result.error).toContain("Reload canceled");
});

test("repeated reloads keep search paths and shell hooks unique", () => {
  const state = fixture(`
export PATH="$HOME/bin:$PATH"
fpath=("$HOME/completions" $fpath)
precmd_functions+=(prompt_hook)
preexec_functions+=(exec_hook)
chpwd_functions+=(directory_hook)
`);
  const result = state.run(`
precmd_functions=(prompt_hook)
preexec_functions=(exec_hook)
chpwd_functions=(directory_hook)
reload
reload
typeset -a path_matches
path_matches=("\${(@M)path:#$HOME/bin}")
print -r -- "duplicates=$#path_matches"
print -r -- "first=$path[1]"
print -r -- "prompt=$#precmd_functions exec=$#preexec_functions directory=$#chpwd_functions"
local -a matches
matches=("\${(@M)fpath:#$HOME/completions}")
print -r -- "completions=$#matches"
`);
  expect(result.status).toBe(0);
  expect(result.output).toContain("duplicates=1");
  expect(result.output).toContain(`first=${state.home}/bin`);
  expect(result.output).toContain("prompt=1 exec=1 directory=1");
  expect(result.output).toContain("completions=1");
});

test("dotfile aliases win over stale startup aliases while custom aliases remain", () => {
  const state = fixture(`
alias update='obsolete-update'
alias my_custom_alias='printf custom'
`);
  const result = state.run(`
reload
alias update
alias my_custom_alias
`);
  expect(result.status).toBe(0);
  expect(result.output).toContain("update='bash ~/dotfiles/macos/update.sh'");
  expect(result.output).toContain("my_custom_alias='printf custom'");
});

test("reload honors ZDOTDIR and retains the shell, working directory, and variables", () => {
  const state = fixture("RELOAD_VALUE=wrong\n");
  const config = join(state.home, "custom config");
  mkdirSync(config);
  writeFileSync(join(config, ".zshrc"), "typeset RELOAD_VALUE=correct\n");
  const result = state.run(
    `
before=$$
SHELL_LOCAL_VALUE=retained
reload
print -r -- "value=$RELOAD_VALUE local=$SHELL_LOCAL_VALUE same_shell=$((before == $$)) cwd=$PWD"
`,
    { ZDOTDIR: config },
  );
  expect(result.status).toBe(0);
  expect(result.output).toContain("value=correct local=retained same_shell=1");
  expect(result.output).toContain(`cwd=${state.home}`);
});

test("reload propagates startup failures", () => {
  const result = fixture("return 7\n").run("reload");
  expect(result.status).toBe(7);
});

test.each([
  ["claud", ".claude_personal1"],
  ["claudw", ".claude_work"],
])("%s selects its Claude config without changing the shell environment", (alias, directory) => {
  const state = fixture("");
  const result = state.run(`
claude() {
  printf '%s\\0' "$CLAUDE_CONFIG_DIR" "$@"
  return 7
}
CLAUDE_CONFIG_DIR=original
${alias} --resume 'session with spaces'
result=$?
printf '%s\\0' "$result" "$CLAUDE_CONFIG_DIR"
`);
  expect(result.status).toBe(0);
  expect(result.error).toBe("");
  expect(result.output.split("\0")).toEqual([
    join(state.home, directory),
    "--resume",
    "session with spaces",
    "7",
    "original",
    "",
  ]);
});
