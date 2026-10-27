#!/usr/bin/env python3
"""Build and package the separate Streamlined edition with official Defold Bob."""

from pathlib import Path
import argparse
import configparser
import hashlib
import json
import os
import shutil
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[2]
TARGETS = {"windows": "x86_64-win32", "linux": "x86_64-linux", "html5": "wasm-web"}
TITLE = "Behind the Screen - Streamlined"


def require_path(value, label):
    path = Path(value).expanduser().resolve()
    if not path.is_file():
        raise SystemExit(f"{label} not found: {path}")
    return path


def credits():
    return (
        "Behind the Screen - Streamlined\n\n"
        "Built with Defold 1.13.2. https://defold.com\n\n"
        'This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") '
        "by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. "
        "The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, "
        "available at https://creativecommons.org/licenses/by/4.0/legalcode. "
        "The rules code paraphrases it and cites page numbers.\n\n"
        "Fonts: Outfit, Lora and Nothing You Could Do, under the SIL Open Font License. "
        "The complete font licenses are included in the licenses folder.\n"
    )


def package_target(target, stage, destination):
    folders = [p for p in stage.iterdir() if p.is_dir()]
    if len(folders) != 1:
        raise SystemExit(f"Expected one application bundle in {stage}, found {len(folders)}.")
    game = folders[0]
    config_file = game / ("archive/game0.projectc" if target == "html5" else "game.projectc")
    config = configparser.ConfigParser(interpolation=None)
    config.read(config_file, encoding="utf-8")
    if config.get("project", "title", fallback="") != TITLE or config.get("streamlined", "enabled", fallback="0") != "1":
        raise SystemExit(f"Bundle is not the enabled Streamlined edition: {config_file}")
    if config.get("streamlined", "autotest", fallback="0") != "0":
        raise SystemExit("Refusing to distribute a bundle with the automated test player enabled.")
    suffix = {"windows": ".exe", "linux": ".x86_64", "html5": ".html"}[target]
    entries = list(game.glob("*" + suffix))
    if not entries:
        raise SystemExit(f"Build finished without a {target} entry point in {game}.")
    if target == "html5":
        if not (game / "index.html").is_file():
            raise SystemExit(f"HTML5 bundle has no index.html: {game}")
        shutil.copy2(ROOT / "tools/build/serve_local.py", game / "serve_local.py")
        how = (
            "Install Python 3 if needed, then run:\n\n"
            "    python serve_local.py\n\n"
            "The game opens in your browser at http://127.0.0.1:8000/. "
            "Keep the terminal open while playing. Double-clicking index.html will not load "
            "the WebAssembly game; use the included local server.\n"
        )
    elif target == "windows":
        how = f"Extract the whole ZIP, then double-click {entries[0].name}.\n"
    else:
        how = f"Extract the whole ZIP, then run ./{entries[0].name} from its folder.\n"
    readme = (
        f"{TITLE}\n\n{how}\n"
        "This is the separate Streamlined edition of the original Defold game. "
        "Keep all bundled files together. The streamlined save is separate from the original campaign.\n\n"
        "Click the on-screen choices. Follow the displayed next-step button to move through each evening.\n"
    )
    (game / "READ_ME_FIRST.txt").write_text(readme, encoding="utf-8")
    (game / "CREDITS.txt").write_text(credits(), encoding="utf-8")
    licenses = game / "licenses"
    licenses.mkdir(exist_ok=True)
    for license_file in sorted((ROOT / "assets/fonts").glob("*-OFL.txt")):
        shutil.copy2(license_file, licenses / license_file.name)
    archive = destination / f"Behind-the-Screen-Streamlined-{target}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for file in sorted(game.rglob("*")):
            if file.is_file():
                z.write(file, file.relative_to(stage))
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    print(f"Ready: {archive} ({archive.stat().st_size / 1048576:.1f} MiB)", flush=True)
    return {"target": target, "platform": TARGETS[target], "file": archive.name,
            "bytes": archive.stat().st_size, "sha256": digest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bob", default=os.environ.get("BOB"), help="Path to official Defold 1.13.2 bob.jar")
    parser.add_argument("--java", default=os.environ.get("JAVA", "java"), help="Java 25 executable")
    parser.add_argument("--target", action="append", choices=[*TARGETS, "all"], help="Repeat to select targets; default windows")
    parser.add_argument("--variant", choices=["release", "debug"], default="release")
    parser.add_argument("--dist", type=Path, default=ROOT / "dist/streamlined")
    parser.add_argument("--clean", action="store_true", help="Clean only this edition's target build directory")
    args = parser.parse_args()
    if not args.bob:
        parser.error("Pass --bob /path/to/bob.jar or set BOB. Use official Defold 1.13.2.")
    bob = require_path(args.bob, "Bob")
    java = shutil.which(args.java) or (str(Path(args.java).expanduser()) if Path(args.java).expanduser().is_file() else None)
    if not java:
        parser.error("Java 25 not found. Pass --java /path/to/java or set JAVA.")
    targets = args.target or ["windows"]
    targets = list(TARGETS) if "all" in targets else list(dict.fromkeys(targets))
    destination = args.dist.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    manifest = []
    for target in targets:
        build = ROOT / "build/streamlined" / target
        stage = destination / target
        build.mkdir(parents=True, exist_ok=True)
        stage.mkdir(parents=True, exist_ok=True)
        log = build / "bob.log"
        cmd = [java, "-Xmx3g", "-jar", str(bob), "--root", ".",
               "--output", str(build.relative_to(ROOT)), "--platform", TARGETS[target],
               "--variant", args.variant, "--max-cpu-threads", "4", "--archive",
               "--settings", "tools/build/streamlined.ini",
               "--bundle-output", str(stage)]
        if target == "html5":
            cmd.extend(["--architectures", "wasm-web"])
        if args.clean:
            cmd.append("clean")
        cmd.extend(["build", "bundle"])
        print(f"Building {target} with Defold. Log: {log}", flush=True)
        with log.open("w", encoding="utf-8") as output:
            completed = subprocess.run(cmd, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        if completed.returncode:
            print("\n".join(log.read_text(encoding="utf-8", errors="replace").splitlines()[-40:]), file=sys.stderr)
            raise SystemExit(f"Build failed ({completed.returncode}). Full log: {log}")
        manifest.append(package_target(target, stage, destination))
    manifest_path = destination / "build-manifest.json"
    previous = []
    if manifest_path.exists():
        previous = json.loads(manifest_path.read_text(encoding="utf-8")).get("packages", [])
    by_target = {item["target"]: item for item in previous}
    by_target.update({item["target"]: item for item in manifest})
    manifest_path.write_text(json.dumps({"title": TITLE, "defold": "1.13.2", "variant": args.variant,
                                         "packages": list(by_target.values())}, indent=2) + "\n", encoding="utf-8")
    print(f"Checksums: {manifest_path}", flush=True)


if __name__ == "__main__":
    main()
