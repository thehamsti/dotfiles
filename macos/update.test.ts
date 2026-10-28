import { afterEach, expect, test } from "bun:test";
import { copyFileSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const script = join(import.meta.dir, "update.sh");
const dotfiles = resolve(import.meta.dir, "..");
const fixtures: string[] = [];

afterEach(() => {
  for (const directory of fixtures.splice(0)) rmSync(directory, { recursive: true });
});

function fixture() {
  const directory = mkdtempSync(join(tmpdir(), "dotfiles-update-"));
  fixtures.push(directory);
  const bin = join(directory, "bin");
  const home = join(directory, "home");
  mkdirSync(bin);
  mkdirSync(home);
  const log = join(directory, "calls");
  writeFileSync(log, "");
  for (const command of ["mise", "brew", "bun", "sudo", "sleep"]) {
    writeFileSync(
      join(bin, command),
      `#!/bin/bash
name="\${0##*/}"
[[ "$name" == sleep ]] && exit 1
{
    printf '%s' "$name"
    printf ' <%s>' "$@"
    printf ' [yes=%s askpass=%s no-autoremove=%s]\\n' "$HOMEBREW_NO_ASK" "$SUDO_ASKPASS" "$HOMEBREW_NO_AUTOREMOVE"
} >> "$CALL_LOG"
if [[ "$name $*" == "\${FAIL_COMMAND:-}" ]]; then exit 7; fi
if [[ "$name" == mise && "$1" == which ]]; then printf '%s/probe\\n' "$FAKE_BIN"; fi
if [[ "$name" == mise && "$1" == exec && -n "\${FAIL_PROBE:-}" ]]; then exit 9; fi
if [[ "$name" == brew && "$1" == list ]]; then [[ ! -e "$TEST_STATE/removed-$3" ]]; exit; fi
if [[ "$name" == brew && "$1" == --cellar ]]; then echo "$TEST_STATE/cellar"; fi
if [[ "$name" == brew && "$1" == uses ]]; then echo "\${DEPENDENTS:-}"; fi
if [[ "$name" == brew && "$1" == uninstall ]]; then touch "$TEST_STATE/removed-$3"; fi
`,
      { mode: 0o755 },
    );
  }
  const env = {
    PATH: `${bin}:/usr/bin:/bin`,
    HOME: home,
    BUN_INSTALL: join(home, ".bun"),
    CALL_LOG: log,
    FAKE_BIN: bin,
    TEST_STATE: directory,
  };
  return {
    home,
    env,
    directory,
    log,
    run(args: string[] = [], overrides: Record<string, string> = {}, cwd = directory) {
      const result = Bun.spawnSync(["/bin/bash", script, ...args], {
        env: { ...env, ...overrides },
        cwd,
      });
      return {
        status: result.exitCode,
        output: result.stdout.toString() + result.stderr.toString(),
        calls: readFileSync(log, "utf8"),
      };
    },
    withGlobals() {
      const manifest = join(home, ".bun/install/global/package.json");
      mkdirSync(dirname(manifest), { recursive: true });
      writeFileSync(manifest, '{"dependencies":{"example":"1.0.0"}}');
    },
  };
}

test("authenticates once, uses explicit yes flags, and does not invoke Nix", () => {
  const result = fixture().run();
  expect(result.status).toBe(0);
  expect(result.calls.match(/^sudo <-v>/gm)).toHaveLength(1);
  expect(result.calls).toContain("mise <upgrade> <--global> <--yes>");
  expect(result.calls).toContain("brew <upgrade> <--formula> <--yes>");
  expect(result.calls).toContain("brew <upgrade> <--cask> <--yes>");
  expect(result.calls).toContain(
    "sudo <-n> <softwareupdate> <--install> <--all> <--agree-to-license>",
  );
  expect(result.calls).toContain("[yes=1 askpass=/usr/bin/false no-autoremove=1]");
  expect(result.calls).not.toContain("--restart");
  expect(result.calls).not.toContain("nix");
});

test("Homebrew updates mise before installing complete plugins and upgrading tools", () => {
  const result = fixture().run(["--no-system"]);
  expect(result.status).toBe(0);
  const brew = result.calls.indexOf("brew <upgrade> <--formula> <--yes>");
  const install = result.calls.indexOf(
    "mise <plugins> <install> <vfox:gcloud> <https://github.com/jdx/vfox-gcloud.git>",
  );
  const plugins = result.calls.indexOf("mise <plugins> <update>");
  const upgrade = result.calls.indexOf("mise <upgrade> <--global> <--yes>");
  const shims = result.calls.indexOf("mise <reshim>");
  expect(install).toBeGreaterThan(brew);
  expect(plugins).toBeGreaterThan(install);
  expect(upgrade).toBeGreaterThan(plugins);
  expect(shims).toBeGreaterThan(upgrade);
});

test("an installed filesystem gcloud plugin is updated without reinstall warnings", () => {
  const state = fixture();
  const plugin = join(state.home, ".local/share/mise/plugins/gcloud");
  mkdirSync(plugin, { recursive: true });
  writeFileSync(join(plugin, "metadata.lua"), "PLUGIN = {}\n");
  const result = state.run(["--no-system"]);
  expect(result.status).toBe(0);
  expect(result.calls).not.toContain("mise <plugins> <install>");
  expect(result.calls).toContain("mise <plugins> <update>");
  expect(result.calls).toContain("mise <upgrade> <--global> <--yes>");
});

test.each([
  "mise plugins install vfox:gcloud https://github.com/jdx/vfox-gcloud.git",
  "mise plugins update",
])(
  "a failed plugin preparation step prevents tool upgrades and shim regeneration: %s",
  (command) => {
    const state = fixture();
    state.withGlobals();
    const result = state.run(["--no-system"], { FAIL_COMMAND: command });
    expect(result.status).toBe(1);
    expect(result.calls).not.toContain("mise <upgrade>");
    expect(result.calls).not.toContain("mise <reshim>");
    expect(result.calls).toContain("brew <upgrade> <--cask> <--yes>");
    expect(result.output).toContain("Upgrade Bun global packages");
  },
);

function migrationFixture() {
  const state = fixture();
  const project = join(state.directory, "project");
  const macos = join(project, "macos");
  mkdirSync(macos, { recursive: true });
  for (const name of ["mise.sh", "migrate_to_mise.sh", "git_credentials.sh"]) {
    copyFileSync(join(import.meta.dir, name), join(macos, name));
  }
  writeFileSync(join(project, "mise.toml"), '[tools]\nact = "latest"\n');
  writeFileSync(join(macos, "mise-migrations.tsv"), "formula\tact\tact\tact\t--version\n");
  return {
    ...state,
    runMigration(args: string[] = [], overrides: Record<string, string> = {}) {
      const result = Bun.spawnSync(["/bin/bash", join(macos, "migrate_to_mise.sh"), ...args], {
        env: { ...state.env, ...overrides },
      });
      return {
        status: result.exitCode,
        output: result.stdout.toString() + result.stderr.toString(),
        calls: readFileSync(state.log, "utf8"),
      };
    },
  };
}

test("migration checks replacements without uninstalling by default", () => {
  const result = migrationFixture().runMigration();
  expect(result.status).toBe(0);
  expect(result.calls).toContain("mise <which> <--tool> <act> <act>");
  expect(result.calls).toContain("mise <exec> <act>");
  expect(result.calls).not.toContain("brew <uninstall>");
});

test("fresh mise setup prepares the full gcloud plugin before installing tools", () => {
  const result = migrationFixture().runMigration();
  expect(result.status).toBe(0);
  const plugin = result.calls.indexOf(
    "mise <plugins> <install> <vfox:gcloud> <https://github.com/jdx/vfox-gcloud.git>",
  );
  const install = result.calls.indexOf("<install> <--yes>");
  expect(plugin).toBeGreaterThanOrEqual(0);
  expect(install).toBeGreaterThan(plugin);
});

test("a failed replacement prevents all Homebrew removal", () => {
  const result = migrationFixture().runMigration(["--remove-homebrew"], { FAIL_PROBE: "1" });
  expect(result.status).toBe(9);
  expect(result.calls).not.toContain("brew <uninstall>");
});

test("a package required by other Homebrew installs is retained", () => {
  const result = migrationFixture().runMigration(["--remove-homebrew"], {
    DEPENDENTS: "native-consumer",
  });
  expect(result.status).toBe(0);
  expect(result.calls).toContain("brew <uses> <--installed> <act>");
  expect(result.calls).not.toContain("brew <uninstall>");
});

test("dependency checks use the installed recipe when upstream taps have moved", () => {
  const state = migrationFixture();
  const recipe = join(state.directory, "cellar/act/1.0/.brew/act.rb");
  mkdirSync(dirname(recipe), { recursive: true });
  writeFileSync(recipe, "class Act < Formula; end\n");
  const result = state.runMigration(["--remove-homebrew"]);
  expect(result.status).toBe(0);
  expect(result.calls).toContain(`brew <uses> <--installed> <${recipe}>`);
});

test("verified leaf packages are removed without bypassing dependency protection", () => {
  const result = migrationFixture().runMigration(["--remove-homebrew"]);
  expect(result.status).toBe(0);
  expect(result.calls).toContain("brew <uninstall> <--formula> <act>");
  expect(result.calls).not.toContain("--ignore-dependencies");
  const uninstall = result.calls.split("\n").find((line) => line.startsWith("brew <uninstall>"));
  expect(uninstall).not.toContain("--force");
  expect(uninstall).toContain("no-autoremove=1");
});

test("setup preserves existing mise config and does not install over it", () => {
  const state = migrationFixture();
  mkdirSync(join(state.home, ".config/mise"), { recursive: true });
  const config = join(state.home, ".config/mise/config.toml");
  writeFileSync(config, '[tools]\nnode = "22"\n');
  const result = state.runMigration();
  expect(result.status).toBe(1);
  expect(result.output).toContain("Existing mise config");
  expect(readFileSync(config, "utf8")).toContain('node = "22"');
  expect(result.calls).toBe("");
});

test("repeated setup does not duplicate shell integration", () => {
  const state = migrationFixture();
  expect(state.runMigration().status).toBe(0);
  expect(state.runMigration().status).toBe(0);
  for (const name of [".zprofile", ".zshrc"]) {
    const text = readFileSync(join(state.home, name), "utf8");
    expect(text.match(/# mise tools/g)).toHaveLength(1);
  }
});

test("noninteractive mode never runs an interactive sudo command", () => {
  const result = fixture().run(["--non-interactive"]);
  expect(result.status).toBe(0);
  expect(result.calls).toContain("sudo <-n> <-v>");
  expect(result.calls).not.toContain("sudo <-v>");
});

test("unavailable sudo is reported while package updates continue", () => {
  const result = fixture().run(["--non-interactive"], { FAIL_COMMAND: "sudo -n -v" });
  expect(result.status).toBe(1);
  expect(result.output).toContain("sudo unavailable");
  expect(result.calls).toContain("mise <upgrade>");
  expect(result.calls).toContain("brew <upgrade>");
  expect(result.calls).not.toContain("softwareupdate");
});

test("no-system mode does not authenticate or install macOS updates", () => {
  const result = fixture().run(["--no-system"]);
  expect(result.status).toBe(0);
  expect(result.calls).not.toContain("sudo");
  expect(result.calls).not.toContain("softwareupdate");
});

test("dry-run prints commands and makes no external calls", () => {
  const result = fixture().run(["--dry-run"]);
  expect(result.status).toBe(0);
  expect(result.calls).toBe("");
  expect(result.output).toContain("mise upgrade --global --yes");
  expect(result.output).toContain("brew upgrade --cask --yes");
  expect(result.output).toContain("--agree-to-license");
});

test("failed metadata refresh does not upgrade from stale metadata", () => {
  const result = fixture().run(["--no-system"], { FAIL_COMMAND: "brew update" });
  expect(result.status).toBe(1);
  expect(result.calls).not.toContain("brew <upgrade>");
  expect(result.calls).not.toContain("brew <cleanup>");
});

test("independent failures accumulate and do not hide later work", () => {
  const result = fixture().run([], { FAIL_COMMAND: "brew upgrade --formula --yes" });
  expect(result.status).toBe(1);
  expect(result.output).toContain("Upgrade remaining Homebrew formulae (exit 7)");
  expect(result.calls).toContain("brew <upgrade> <--cask>");
  expect(result.calls).toContain("softwareupdate");
});

test("Bun globals update from the dotfiles config instead of the caller's project", () => {
  const state = fixture();
  state.withGlobals();
  const result = state.run(["--no-system"]);
  expect(result.status).toBe(0);
  expect(result.calls).toContain(
    `mise <-C> <${dotfiles}> <exec> <bun@latest> <--> <bun> <update> <--global> <--latest>`,
  );
});

test("Bun global updates override an inherited project Bun version", () => {
  const state = fixture();
  state.withGlobals();
  const result = state.run(["--no-system"], { MISE_BUN_VERSION: "1.4.2" });
  expect(result.status).toBe(0);
  expect(result.calls).toContain(
    `mise <-C> <${dotfiles}> <exec> <bun@latest> <--> <bun> <update> <--global> <--latest>`,
  );
});

test("missing Bun globals are skipped", () => {
  const result = fixture().run(["--no-system"]);
  expect(result.status).toBe(0);
  expect(result.calls).not.toContain("<bun> <update>");
});

test("unknown options fail before doing any work", () => {
  const result = fixture().run(["--wat"]);
  expect(result.status).toBe(2);
  expect(result.calls).toBe("");
});

test("help does not authenticate or update", () => {
  const result = fixture().run(["--help"]);
  expect(result.status).toBe(0);
  expect(result.calls).toBe("");
  expect(result.output).toContain("--non-interactive");
});

test("each migration maps to a configured tool and preserves runtime ranges", async () => {
  const config = Bun.TOML.parse(await Bun.file(join(dotfiles, "mise.toml")).text()) as {
    tools: Record<string, unknown>;
  };
  const rows = (await Bun.file(join(import.meta.dir, "mise-migrations.tsv")).text())
    .trim()
    .split("\n")
    .filter((line) => !line.startsWith("#"));
  const names = new Set();
  for (const row of rows) {
    const [kind, name, tool, executable, probe] = row.split("\t");
    expect(["formula", "cask"]).toContain(kind);
    expect(names.has(`${kind}:${name}`)).toBe(false);
    names.add(`${kind}:${name}`);
    expect(config.tools[tool.replace(/@\d[\d.]*$/, "")]).toBeDefined();
    expect(executable).toBeTruthy();
    expect(probe).toBeTruthy();
  }
  expect(config.tools.node).toBe("lts");
  expect(config.tools.dotnet).toEqual(["10", "8"]);
  expect(config.tools.terraform).toBe("1.5");
  expect(config.tools["pypi:antoniorodr/memo"]).toBe("latest");
  expect(config.tools["pypi:memo"]).toBeUndefined();
});
