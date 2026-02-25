import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const home = (process.env.USERPROFILE ?? process.env.HOME ?? "").replace(/\\/g, "/");
const installed = JSON.parse(await Bun.file(`${home}/.claude/plugins/installed_plugins.json`).text());
const entry = installed.plugins["claude-tools@claude-tools"]?.[0];
if (!entry) process.exit(0);

const installPath = (entry.installPath as string).replace(/\\/g, "/");

if (process.platform === "win32") {
  spawnSync("pwsh", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    resolve(installPath, "scripts/win/statusline.ps1")], { stdio: "inherit" });
} else {
  spawnSync("bash", [resolve(installPath, "scripts/linux/statusline.sh")], { stdio: "inherit" });
}
