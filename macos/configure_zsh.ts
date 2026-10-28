import { chmodSync, copyFileSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

function quote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

export function configureZsh(content: string, directory: string): string {
  const startup = `source ${quote(join(directory, "zsh_startup.zsh"))}`;
  const completions = `source ${quote(join(directory, "zsh_completions.zsh"))}`;
  let result = content;
  result = result.replace(/^\[ -s "\$NVM_DIR\/(?:nvm\.sh|bash_completion)" \] &&.*$/gm, "");
  result = result.replace(/^eval "\$\(codex completion zsh\)"$/gm, "");
  result = result.replace(
    /# The following lines have been added by Docker Desktop to enable Docker CLI completions\.\n(?:fpath=.*\n)autoload -Uz compinit\ncompinit\n# End of Docker CLI completions\n/g,
    "",
  );
  if (/^eval "\$\(starship init zsh\)"$/m.test(result)) {
    result = result.replace(/^ZSH_THEME="robbyrussell"$/m, 'ZSH_THEME=""');
  }
  let bunSeen = false;
  result = result.replace(
    /# [Bb]un\nexport BUN_INSTALL="\$HOME\/\.bun"\nexport PATH="\$BUN_INSTALL\/bin:\$PATH"\n/g,
    (block) => {
      if (bunSeen) return "";
      bunSeen = true;
      return block;
    },
  );
  if (!result.split("\n").includes(startup)) result = `${startup}\n${result}`;
  if (!result.split("\n").includes(completions)) result = `${result.trimEnd()}\n\n${completions}\n`;
  return result;
}

if (import.meta.main) {
  const profile = process.argv[2];
  if (!profile) throw new Error("Usage: bun configure_zsh.ts /path/to/.zshrc");
  const original = readFileSync(profile, "utf8");
  const configured = configureZsh(original, import.meta.dir);
  if (configured !== original) {
    const backup = mkdtempSync(`${profile}.backup.`);
    copyFileSync(profile, join(backup, "original"));
    chmodSync(join(backup, "original"), 0o600);
    const candidate = join(backup, "configured.zsh");
    writeFileSync(candidate, configured, { mode: 0o600 });
    const checked = Bun.spawnSync(["/bin/zsh", "-n", candidate], {
      stdout: "ignore",
      stderr: "ignore",
    });
    if (checked.exitCode !== 0)
      throw new Error(`Zsh syntax check failed; ${profile} was not changed. Backup: ${backup}`);
    writeFileSync(profile, configured);
    console.log(`Zsh startup optimized. Previous config saved to ${backup}/original`);
  }
}
