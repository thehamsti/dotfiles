import { afterEach, expect, test } from "bun:test";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const homes: string[] = [];
afterEach(() => {
  for (const home of homes.splice(0)) rmSync(home, { recursive: true });
});

function fixture() {
  const home = realpathSync(mkdtempSync(join(tmpdir(), "zsh startup-")));
  homes.push(home);
  const bin = join(home, "bin");
  mkdirSync(bin);
  symlinkSync(process.execPath, join(bin, "bun"));
  for (const plugin of ["zsh-autosuggestions", "zsh-syntax-highlighting", "zsh-completions"]) {
    mkdirSync(join(home, ".oh-my-zsh/custom/plugins", plugin), { recursive: true });
  }
  mkdirSync(join(home, ".docker/completions"), { recursive: true });
  mkdirSync(join(home, "dotfiles/macos"), { recursive: true });
  writeFileSync(join(home, "dotfiles/macos/aliases.sh"), "alias fixture_alias='print fixture'\n");
  mkdirSync(join(home, ".nvm"));
  writeFileSync(join(home, ".nvm/nvm.sh"), "nvm() { :; }\n");
  writeFileSync(
    join(home, ".oh-my-zsh/oh-my-zsh.sh"),
    `
typeset -gA COMPLETER
autoload() { :; }
compinit() {
  print -r -- "$ZSH_THEME:$fpath[1]" >> "$HOME/completion-init"
}
compdef() { COMPLETER[$2]=$1; }
compinit
`,
  );
  writeFileSync(
    join(home, ".zshrc"),
    `ZSH_THEME="robbyrussell"
source "$HOME/.oh-my-zsh/oh-my-zsh.sh"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \\. "$NVM_DIR/bash_completion"
eval "$(codex completion zsh)"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export FIXTURE_CUSTOM_VALUE='preserved value'
`,
  );
  for (const name of ["mise", "fzf", "zoxide", "starship", "direnv", "node"]) {
    writeFileSync(
      join(bin, name),
      `#!/bin/sh\n${name === "node" ? "echo mise-node" : "exit 0"}\n`,
      { mode: 0o755 },
    );
  }
  writeFileSync(
    join(bin, "codex"),
    `#!/bin/sh
echo completion >> "$HOME/codex-loaded"
cat <<'EOF'
_codex() { print -r -- "completed:$*"; return 7; }
compdef _codex codex
EOF
`,
    { mode: 0o755 },
  );
  const env = { HOME: home, PATH: `${bin}:/usr/bin:/bin` };
  return {
    home,
    setup() {
      const result = Bun.spawnSync(["/bin/bash", join(import.meta.dir, "setup_zsh.sh")], {
        env,
        cwd: home,
      });
      return { status: result.exitCode, error: result.stderr.toString() };
    },
    shell(code = "") {
      const result = Bun.spawnSync(
        ["/bin/zsh", "-f", "-c", 'source "$HOME/.zshrc"; eval "$1"', "startup-test", code || ":"],
        { env, cwd: home },
      );
      return {
        status: result.exitCode,
        output: result.stdout.toString(),
        error: result.stderr.toString(),
      };
    },
  };
}

test("startup uses mise's Node and defers Codex generation", () => {
  const state = fixture();
  expect(state.setup().status).toBe(0);
  const result = state.shell('node; print -r -- "$FIXTURE_CUSTOM_VALUE"; fixture_alias');
  expect(result.status).toBe(0);
  expect(result.error).toBe("");
  expect(result.output).toBe("mise-node\npreserved value\nfixture\n");
  expect(readFileSync(join(state.home, ".zshrc"), "utf8")).not.toContain("NVM_DIR");
  expect(existsSync(join(state.home, "codex-loaded"))).toBe(false);
  expect(readFileSync(join(state.home, "completion-init"), "utf8")).toBe(
    `:${state.home}/.docker/completions\n`,
  );
  expect(state.shell("(( $+functions[nvm] ))").status).toBe(1);
});

test("Codex completion generates on first use and then uses the native completer", () => {
  const state = fixture();
  expect(state.setup().status).toBe(0);
  const result = state.shell(
    '"$COMPLETER[codex]" first "two words"; print -r -- "status=$?"; "$COMPLETER[codex]" again; print -r -- "status=$?"',
  );
  expect(result.error).toBe("");
  expect(result.output).toBe("completed:first two words\nstatus=7\ncompleted:again\nstatus=7\n");
  expect(readFileSync(join(state.home, "codex-loaded"), "utf8")).toBe("completion\n");
});

test("invalid Zsh syntax cannot replace the working profile", () => {
  const state = fixture();
  const profile = join(state.home, ".zshrc");
  const original = "if true; then\n";
  writeFileSync(profile, original);
  const result = Bun.spawnSync([
    process.execPath,
    join(import.meta.dir, "configure_zsh.ts"),
    profile,
  ]);
  expect(result.exitCode).toBe(1);
  expect(result.stderr.toString()).toContain("was not changed");
  expect(readFileSync(profile, "utf8")).toBe(original);
});

test("repeated setup preserves custom config and keeps a single private backup", () => {
  const state = fixture();
  const original = readFileSync(join(state.home, ".zshrc"), "utf8");
  expect(state.setup().status).toBe(0);
  const first = readFileSync(join(state.home, ".zshrc"), "utf8");
  expect(state.setup().status).toBe(0);
  expect(readFileSync(join(state.home, ".zshrc"), "utf8")).toBe(first);
  const backups = readdirSync(state.home).filter((name) => name.startsWith(".zshrc.backup."));
  expect(backups).toHaveLength(1);
  const backup = join(state.home, backups[0]);
  expect(readFileSync(join(backup, "original"), "utf8")).toStartWith(original);
  expect(statSync(backup).mode & 0o077).toBe(0);
  expect(state.shell('print -r -- "$FIXTURE_CUSTOM_VALUE"').output).toBe("preserved value\n");
});
