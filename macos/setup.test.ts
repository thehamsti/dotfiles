import { afterEach, expect, test } from "bun:test";
import {
  copyFileSync,
  existsSync,
  lstatSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  statSync,
  symlinkSync,
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
  const home = realpathSync(mkdtempSync(join(tmpdir(), "macos setup-")));
  homes.push(home);
  const bin = join(home, "bin");
  mkdirSync(bin);
  const env: Record<string, string> = {
    HOME: home,
    PATH: `${bin}:/usr/bin:/bin`,
    CALL_LOG: join(home, "calls"),
  };
  writeFileSync(env.CALL_LOG, "");
  return {
    home,
    bin,
    env,
    fake(name: string, body: string) {
      writeFileSync(join(bin, name), `#!/bin/bash\n${body}\n`, { mode: 0o755 });
    },
    run(file: string, args: string[] = []) {
      const result = Bun.spawnSync(["/bin/bash", file, ...args], { env, cwd: home });
      return {
        status: result.exitCode,
        output: result.stdout.toString(),
        error: result.stderr.toString(),
      };
    },
  };
}

test("config links can be installed twice without creating links inside the source", () => {
  const state = fixture();
  const source = join(state.home, "source config");
  const target = join(state.home, "target config");
  mkdirSync(source);
  expect(state.run(join(root, "macos/link_config.sh"), [source, target]).status).toBe(0);
  expect(state.run(join(root, "macos/link_config.sh"), [source, target]).status).toBe(0);
  expect(realpathSync(target)).toBe(source);
  expect(readdirSync(source)).toEqual([]);
});

test("conflicting configs and previous backups are preserved", () => {
  const state = fixture();
  const source = join(state.home, "source");
  const target = join(state.home, "target");
  mkdirSync(source);
  mkdirSync(target);
  writeFileSync(join(target, "custom-settings"), "keep me");
  mkdirSync(`${target}.bak`);
  writeFileSync(join(`${target}.bak`, "older-settings"), "older backup");
  expect(state.run(join(root, "macos/link_config.sh"), [source, target]).status).toBe(0);
  expect(lstatSync(target).isSymbolicLink()).toBe(true);
  expect(readFileSync(join(`${target}.bak`, "older-settings"), "utf8")).toBe("older backup");
  const backup = readdirSync(state.home).find((name) => name.startsWith("target.backup."));
  expect(backup).toBeDefined();
  expect(readFileSync(join(state.home, backup!, "original/custom-settings"), "utf8")).toBe(
    "keep me",
  );
});

test("a missing config source cannot replace an existing user file", () => {
  const state = fixture();
  const target = join(state.home, "target");
  writeFileSync(target, "original");
  expect(
    state.run(join(root, "macos/link_config.sh"), [join(state.home, "missing"), target]).status,
  ).toBe(1);
  expect(readFileSync(target, "utf8")).toBe("original");
});

function backupFixture() {
  const state = fixture();
  state.fake(
    "brew",
    'if [[ "$1 $2" == "bundle dump" && -n "$FAIL_BREW" ]]; then exit 8; fi\nprintf "package inventory\\n"',
  );
  state.fake("mise", 'printf "{}\\n"');
  state.fake("npm", 'printf "{}\\n"');
  state.fake("bun", 'printf "package inventory\\n"');
  state.fake("defaults", 'printf "preferences\\n"');
  state.env.FAIL_BREW = "";
  mkdirSync(join(state.home, ".config/mise"), { recursive: true });
  mkdirSync(join(state.home, ".config/herdr"), { recursive: true });
  writeFileSync(join(state.home, ".config/herdr/config.toml"), "onboarding = false\n");
  writeFileSync(join(state.home, ".config/herdr/session.json"), "private runtime state");
  mkdirSync(join(state.home, ".bun/install/global"), { recursive: true });
  writeFileSync(join(state.home, ".config/mise/config.toml"), '[tools]\nbun = "latest"\n');
  writeFileSync(
    join(state.home, ".bun/install/global/package.json"),
    '{"dependencies":{"example":"1.0.0"}}',
  );
  writeFileSync(join(state.home, ".zprofile"), "profile\n");
  writeFileSync(join(state.home, ".gitconfig"), "git config\n");
  return {
    ...state,
    backup() {
      const result = state.run(join(root, "backup.sh"));
      const name = readdirSync(state.home).find((entry) => entry.startsWith("dotfiles-backup-"));
      expect(name).toBeDefined();
      return { ...result, directory: join(state.home, name!) };
    },
  };
}

test("backups are private and include mise, Herdr, the login profile and Bun manifest", () => {
  const result = backupFixture().backup();
  expect(result.status).toBe(0);
  expect(statSync(result.directory).mode & 0o777).toBe(0o700);
  expect(readFileSync(join(result.directory, "mise-config.toml"), "utf8")).toContain(
    'bun = "latest"',
  );
  expect(readFileSync(join(result.directory, "zprofile"), "utf8")).toBe("profile\n");
  expect(readFileSync(join(result.directory, "herdr-config.toml"), "utf8")).toBe(
    "onboarding = false\n",
  );
  expect(existsSync(join(result.directory, "session.json"))).toBe(false);
  expect(readFileSync(join(result.directory, "bun-global-package.json"), "utf8")).toContain(
    "example",
  );
  expect(statSync(join(result.directory, "gitconfig")).mode & 0o077).toBe(0);
});

test("a failed package export is reported after remaining configuration is backed up", () => {
  const state = backupFixture();
  state.env.FAIL_BREW = "1";
  const result = state.backup();
  expect(result.status).toBe(1);
  expect(result.output + result.error).toContain("Homebrew");
  expect(readFileSync(join(result.directory, "gitconfig"), "utf8")).toBe("git config\n");
  expect(existsSync(join(result.directory, "RESTORE.md"))).toBe(true);
});

test("generated Zsh initialization evaluates hook output without literal quote characters", () => {
  const state = fixture();
  symlinkSync(process.execPath, join(state.bin, "bun"));
  for (const plugin of ["zsh-autosuggestions", "zsh-syntax-highlighting", "zsh-completions"]) {
    mkdirSync(join(state.home, ".oh-my-zsh/custom/plugins", plugin), { recursive: true });
  }
  mkdirSync(join(state.home, "dotfiles/macos"), { recursive: true });
  writeFileSync(join(state.home, "dotfiles/macos/aliases.sh"), "");
  for (const command of ["mise", "zoxide", "starship", "direnv"]) {
    state.fake(command, `printf 'typeset -g ${command.toUpperCase()}_READY=1\\n'`);
  }
  state.fake("fzf", "exit 0");
  expect(state.run(join(root, "macos/setup_zsh.sh")).status).toBe(0);
  const loaded = Bun.spawnSync(
    [
      "/bin/zsh",
      "-f",
      "-c",
      'source "$HOME/.zshrc"; print -r -- "$MISE_READY:$ZOXIDE_READY:$STARSHIP_READY:$DIRENV_READY"',
    ],
    { env: state.env },
  );
  expect(loaded.exitCode).toBe(0);
  expect(loaded.stdout.toString().trim()).toBe("1:1:1:1");
  expect(loaded.stderr.toString()).toBe("");
});

test("macOS defaults keep quarantine protection and leave working applications open", () => {
  const state = fixture();
  const record = 'printf "%s %s\\n" "${0##*/}" "$*" >> "$CALL_LOG"';
  for (const command of ["defaults", "osascript", "killall"]) state.fake(command, record);
  state.fake("sudo", `${record}\n[[ "$*" != "-n true" ]]`);
  state.fake("sleep", "exit 1");
  expect(state.run(join(root, "macos/macos.sh")).status).toBe(0);
  const calls = readFileSync(state.env.CALL_LOG, "utf8");
  expect(calls).not.toContain("LSQuarantine");
  for (const application of ["Terminal", "Safari", "Mail", "Messages"])
    expect(calls).not.toContain(`killall ${application}\n`);
  expect(calls).toContain("killall Dock\n");
});

test("SSH template preserves OpenSSH's current algorithm defaults", () => {
  function algorithms(file: string) {
    const result = Bun.spawnSync(["/usr/bin/ssh", "-F", file, "-G", "github.com"], {
      stderr: "pipe",
    });
    expect(result.exitCode).toBe(0);
    return result.stdout
      .toString()
      .split("\n")
      .filter((line) => /^(hostkeyalgorithms|kexalgorithms|ciphers|macs) /.test(line));
  }
  expect(algorithms(join(root, "ssh_config"))).toEqual(algorithms("/dev/null"));
});

test("Git setup removes the global FSMonitor prompt stall while preserving repository opt-ins", () => {
  const state = fixture();
  writeFileSync(
    join(state.home, ".gitconfig"),
    "[core]\nfsmonitor = true\n[user]\nname = Fixture User\n",
  );
  const repository = join(state.home, "repository");
  function git(args: string[]) {
    const result = Bun.spawnSync(["/usr/bin/git", ...args], { env: state.env, cwd: state.home });
    expect(result.exitCode).toBe(0);
    return result.stdout.toString().trim();
  }
  git(["init", "--quiet", repository]);
  git(["-C", repository, "config", "--local", "core.fsmonitor", "true"]);
  expect(state.run(join(root, "macos/git.sh")).status).toBe(0);
  expect(git(["config", "--global", "--get", "core.fsmonitor"])).toBe("false");
  expect(git(["-C", repository, "config", "--get", "core.fsmonitor"])).toBe("true");
  expect(git(["config", "--global", "--get", "user.name"])).toBe("Fixture User");
});

test("Touch ID setup preserves existing policy and installs sudo_local as root with mode 644", () => {
  const state = fixture();
  const pam = join(state.home, "pam");
  mkdirSync(pam);
  const module_dir = realpathSync(mkdtempSync(join(tmpdir(), "pam-module-")));
  homes.push(module_dir);
  const module = join(module_dir, "pam_reattach.so");
  const target = join(pam, "sudo_local");
  writeFileSync(module, "fixture module");
  writeFileSync(join(pam, "sudo"), "main stack untouched\n");
  const original =
    "auth required existing_policy.so # mentions pam_tid.so\n# custom comment\nauth sufficient pam_tid.so\n";
  writeFileSync(target, original);
  state.fake(
    "sudo",
    `
printf '%s\\n' "$*" >> "$CALL_LOG"
if [[ "$1" == install ]]; then
    previous=""; last=""
    for argument in "$@"; do previous="$last"; last="$argument"; done
    cp "$previous" "$last"
    chmod 644 "$last"
else
    "$@"
fi
`,
  );
  expect(state.run(join(root, "macos/setup_sudo.sh"), [module, target]).status).toBe(0);
  const result = readFileSync(target, "utf8");
  expect(result).toContain("pam_reattach.so ignore_ssh");
  expect(result.indexOf("existing_policy.so")).toBeLessThan(result.indexOf("pam_reattach.so"));
  expect(result.indexOf("pam_reattach.so")).toBeLessThan(
    result.indexOf("auth sufficient pam_tid.so"),
  );
  expect(result).toContain("# custom comment");
  expect(readFileSync(join(pam, "sudo"), "utf8")).toBe("main stack untouched\n");
  const backup = readdirSync(pam).find((name) => name.startsWith("sudo_local.backup."));
  expect(backup).toBeDefined();
  expect(readFileSync(join(pam, backup!), "utf8")).toBe(original);
  expect(readFileSync(state.env.CALL_LOG, "utf8")).toContain("install -o root -g wheel -m 644");
  expect(statSync(target).mode & 0o777).toBe(0o644);
  expect(state.run(join(root, "macos/setup_sudo.sh"), [module, target]).status).toBe(0);
  expect(readFileSync(target, "utf8")).toBe(result);
  expect(readdirSync(pam).filter((name) => name.startsWith("sudo_local.backup."))).toHaveLength(1);
});

test("Touch ID setup rejects a missing module without modifying the existing stack", () => {
  const state = fixture();
  const target = join(state.home, "sudo_local");
  writeFileSync(target, "original policy\n");
  expect(
    state.run(join(root, "macos/setup_sudo.sh"), [join(state.home, "missing.so"), target]).status,
  ).toBe(1);
  expect(readFileSync(target, "utf8")).toBe("original policy\n");
});

test("tmux Powerline uses mise's shims and preserves arguments containing spaces", () => {
  const state = fixture();
  const shims = join(state.home, "custom mise/shims");
  mkdirSync(shims, { recursive: true });
  writeFileSync(
    join(shims, "powerline-daemon"),
    '#!/bin/sh\nprintf "%s" "$*" > "$HOME/daemon-started"\n',
    { mode: 0o755 },
  );
  writeFileSync(join(shims, "powerline-config"), '#!/bin/sh\nprintf "%s\\0" "$@" > "$CALL_LOG"\n', {
    mode: 0o755,
  });
  state.env.MISE_DATA_DIR = join(state.home, "custom mise");
  expect(state.run(join(root, "tmux/scripts/setup-powerline.sh")).status).toBe(0);
  expect(readFileSync(join(state.home, "daemon-started"), "utf8")).toBe("-q");
  expect(readFileSync(state.env.CALL_LOG, "utf8").split("\0")).toEqual([
    "-p",
    join(state.home, ".config/powerline"),
    "tmux",
    "setup",
    "",
  ]);
});

test("full setup can be repeated without nesting links or installing user pip packages", () => {
  const state = fixture();
  const project = join(state.home, "project");
  mkdirSync(join(project, "macos"), { recursive: true });
  copyFileSync(join(root, "setup_macos.sh"), join(project, "setup_macos.sh"));
  for (const name of ["link_config.sh", "setup_sudo.sh"])
    copyFileSync(join(root, "macos", name), join(project, "macos", name));
  for (const name of [
    "macos.sh",
    "brew.sh",
    "mise.sh",
    "setup_zsh.sh",
    "herdr.sh",
    "skills.sh",
    "python.sh",
    "git.sh",
  ]) {
    writeFileSync(join(project, "macos", name), '#!/bin/bash\ntouch "$HOME/.zshrc"\n', {
      mode: 0o755,
    });
  }
  writeFileSync(
    join(project, "macos/mise.sh"),
    '#!/bin/bash\n[[ "$HOMEBREW_PREFIX" == "$HOME/homebrew" ]]\n',
    { mode: 0o755 },
  );
  for (const name of ["neovim/nvim", "tmux/scripts", "powerline", "tmuxinator", "agents"])
    mkdirSync(join(project, name), { recursive: true });
  for (const name of ["tmux/tmux.conf", "starship.toml", "gitignore_global", "ssh_config"])
    writeFileSync(join(project, name), "fixture config\n");
  state.fake("sudo", 'printf "%s\\n" "$*" >> "$CALL_LOG"');
  state.fake(
    "brew",
    'case "$1" in shellenv) printf "export HOMEBREW_PREFIX=%q\\n" "$HOME/homebrew";; --prefix) printf "%s\\n" "$HOME/homebrew";; esac',
  );
  state.fake("tmux", "exit 0");
  state.fake("mise", "exit 0");
  state.fake("git", "exit 0");
  state.fake("sleep", "exit 1");
  state.fake("python3", 'printf "python3 %s\\n" "$*" >> "$CALL_LOG"');
  const script = join(project, "setup_macos.sh");
  expect(state.run(script).status).toBe(0);
  expect(state.run(script).status).toBe(0);
  expect(readdirSync(join(project, "neovim/nvim"))).toEqual([]);
  expect(readFileSync(state.env.CALL_LOG, "utf8")).not.toContain("-m pip install");
  expect(realpathSync(join(state.home, ".config/nvim"))).toBe(join(project, "neovim/nvim"));
  const profile = readFileSync(join(state.home, ".zprofile"), "utf8");
  expect(profile.match(/shellenv/g)).toHaveLength(1);
  const loaded = Bun.spawnSync(
    ["/bin/zsh", "-f", "-c", 'source "$HOME/.zprofile"; print -r -- "$HOMEBREW_PREFIX"'],
    { env: state.env },
  );
  expect(loaded.exitCode).toBe(0);
  expect(loaded.stdout.toString().trim()).toBe(join(state.home, "homebrew"));
});

test("tmux project creation does not switch to a session matching only a prefix", () => {
  const state = fixture();
  const directory = join(state.home, "project");
  mkdirSync(directory);
  state.fake(
    "tmux",
    `
printf '%s\\n' "$*" >> "$CALL_LOG"
if [[ "$1" == has-session && "$3" == =project ]]; then exit 1; fi
`,
  );
  expect(
    state.run(join(root, "tmux/scripts/new-project-session.sh"), ["--dir", directory]).status,
  ).toBe(0);
  expect(readFileSync(state.env.CALL_LOG, "utf8")).toContain("new-session -d -s project -c");
});

test("tmux project creation accepts dotted directory names", () => {
  const state = fixture();
  const directory = join(state.home, "project.name");
  mkdirSync(directory);
  state.fake(
    "tmux",
    `
printf '%s\\n' "$*" >> "$CALL_LOG"
if [[ "$1" == has-session ]]; then exit 1; fi
if [[ "$1" == new-session && ( "$4" == *.* || "$#" != 6 ) ]]; then exit 1; fi
`,
  );
  expect(
    state.run(join(root, "tmux/scripts/new-project-session.sh"), ["--dir", directory]).status,
  ).toBe(0);
  expect(readFileSync(state.env.CALL_LOG, "utf8")).toContain("new-session -d -s project_name -c");
});
