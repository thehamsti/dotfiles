import { afterEach, expect, test } from "bun:test";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  realpathSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dir, "..");
const homes: string[] = [];
const defaults = [
  ".agents",
  ".codex",
  ".claude",
  ".claude_personal1",
  ".claude_work",
  ".grok",
  ".cursor",
  ".config/opencode",
  ".pi/agent",
];

afterEach(() => {
  for (const home of homes.splice(0)) rmSync(home, { recursive: true });
});

function fixture() {
  const home = realpathSync(mkdtempSync(join(tmpdir(), "shared skills-")));
  homes.push(home);
  const project = join(home, "dotfiles with spaces");
  const source = join(project, "agents/skills/pr-ready");
  mkdirSync(source, { recursive: true });
  mkdirSync(join(project, "macos"));
  copyFileSync(join(root, "agents/skills/pr-ready/SKILL.md"), join(source, "SKILL.md"));
  for (const name of ["skills.sh", "link_config.sh"])
    copyFileSync(join(root, "macos", name), join(project, "macos", name));
  const env: Record<string, string> = { HOME: home, PATH: "/usr/bin:/bin" };
  return {
    home,
    project,
    source,
    env,
    run() {
      const result = Bun.spawnSync(["/bin/bash", join(project, "macos/skills.sh")], {
        env,
        cwd: home,
      });
      return {
        status: result.exitCode,
        output: result.stdout.toString() + result.stderr.toString(),
      };
    },
  };
}

test("the shared PR skill is installed for all six agents and all three Claude profiles", () => {
  const state = fixture();
  const unrelated = join(state.home, ".cursor/skills/unrelated");
  mkdirSync(unrelated, { recursive: true });
  writeFileSync(join(unrelated, "SKILL.md"), "keep this skill");
  expect(state.run().status).toBe(0);
  for (const directory of defaults) {
    const target = join(state.home, directory, "skills/pr-ready");
    expect(realpathSync(target)).toBe(state.source);
    expect(readFileSync(join(target, "SKILL.md"), "utf8")).toBe(
      readFileSync(join(state.source, "SKILL.md"), "utf8"),
    );
  }
  expect(readFileSync(join(unrelated, "SKILL.md"), "utf8")).toBe("keep this skill");
});

test("repeated skill setup does not nest links or create redundant backups", () => {
  const state = fixture();
  expect(state.run().status).toBe(0);
  expect(state.run().status).toBe(0);
  expect(readdirSync(state.source)).toEqual(["SKILL.md"]);
  for (const directory of defaults)
    expect(readdirSync(join(state.home, directory, "skills"))).toEqual(["pr-ready"]);
});

test("a shared agents root already pointing at dotfiles cannot move the source skill", () => {
  const state = fixture();
  symlinkSync(join(state.project, "agents"), join(state.home, ".agents"));
  expect(state.run().status).toBe(0);
  expect(realpathSync(join(state.home, ".agents/skills/pr-ready"))).toBe(state.source);
  expect(readdirSync(state.source)).toEqual(["SKILL.md"]);
});

test("skill setup honors custom agent directories and keeps the named Claude profiles", () => {
  const state = fixture();
  state.env.CODEX_HOME = join(state.home, "custom codex");
  state.env.CLAUDE_CONFIG_DIR = join(state.home, "custom claude");
  state.env.PI_CODING_AGENT_DIR = join(state.home, "custom pi");
  state.env.XDG_CONFIG_HOME = join(state.home, "custom config");
  expect(state.run().status).toBe(0);
  for (const target of [
    join(state.env.CODEX_HOME, "skills/pr-ready"),
    join(state.env.CLAUDE_CONFIG_DIR, "skills/pr-ready"),
    join(state.env.PI_CODING_AGENT_DIR, "skills/pr-ready"),
    join(state.env.XDG_CONFIG_HOME, "opencode/skills/pr-ready"),
    join(state.home, ".claude_personal1/skills/pr-ready"),
    join(state.home, ".claude_work/skills/pr-ready"),
  ])
    expect(realpathSync(target)).toBe(state.source);
});

test("a conflicting local skill is backed up without replacing other skills", () => {
  const state = fixture();
  const directory = join(state.home, ".claude/skills");
  const target = join(directory, "pr-ready");
  mkdirSync(target, { recursive: true });
  writeFileSync(join(target, "SKILL.md"), "existing local version");
  expect(state.run().status).toBe(0);
  expect(realpathSync(target)).toBe(state.source);
  const backup = readdirSync(directory).find((name) => name.startsWith("pr-ready.backup."));
  expect(backup).toBeDefined();
  expect(readFileSync(join(directory, backup!, "original/SKILL.md"), "utf8")).toBe(
    "existing local version",
  );
});

test("a missing skill source fails before creating agent configuration", () => {
  const state = fixture();
  rmSync(join(state.source, "SKILL.md"));
  expect(state.run().status).toBe(1);
  expect(existsSync(join(state.home, ".codex"))).toBe(false);
});
