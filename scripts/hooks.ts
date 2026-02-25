import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const event: string = process.argv[2];

if (process.platform === "win32") {
  spawnSync("pwsh", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    resolve(import.meta.dir, `win/${event}.ps1`)], { stdio: "inherit" });
} else {
  spawnSync("bash", [resolve(import.meta.dir, `linux/${event}.sh`)], { stdio: "inherit" });
}
