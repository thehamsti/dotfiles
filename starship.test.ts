import { expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

test("git status renders the stash symbol without a format warning", () => {
  const dir = mkdtempSync(join(tmpdir(), "starship-stash-"));
  const env = {
    ...process.env,
    STARSHIP_CONFIG: resolve(import.meta.dir, "starship.toml"),
    GIT_AUTHOR_NAME: "Test",
    GIT_AUTHOR_EMAIL: "test@example.com",
    GIT_COMMITTER_NAME: "Test",
    GIT_COMMITTER_EMAIL: "test@example.com",
  };
  try {
    const git = (...args: string[]) => {
      const result = Bun.spawnSync(["git", ...args], { cwd: dir, env });
      expect(result.exitCode).toBe(0);
    };
    git("init", "-q");
    writeFileSync(join(dir, "file"), "initial");
    git("add", "file");
    git("commit", "-qm", "initial");
    writeFileSync(join(dir, "file"), "changed");
    git("stash", "-q");

    const result = Bun.spawnSync(["starship", "module", "git_status"], { cwd: dir, env });
    expect(result.exitCode).toBe(0);
    expect(result.stderr.toString()).not.toContain("Error parsing format string");
    expect(result.stdout.toString()).toContain("$");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
