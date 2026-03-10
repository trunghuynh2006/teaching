#!/usr/bin/env python3
"""Enforce inter-service dependency rules declared in deps.yaml.

For each service, scans its source_dir for hardcoded references to the ports
of services it is NOT allowed to call (pattern: :<PORT>).

deps.yaml keys per service:
  may_call   : services this app may reach via HTTP at runtime
  cors_from  : services whose port appears only as a CORS AllowedOrigin —
               not an outbound call, so excluded from violation checks

Exit codes:
  0 — no violations
  1 — violations found
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

# Directories and file extensions / name patterns to skip
SKIP_DIRS = {"node_modules", "vendor", "__pycache__", ".git", "dist", "build"}
SKIP_EXTENSIONS = {".lock", ".sum", ".mod", ".png", ".jpg", ".svg", ".ico"}
# Skip .env and .env.example — those are deployment config, not application code
SKIP_NAME_PREFIXES = {".env"}

# Pattern: a colon followed by the port number (URL-style reference)
PORT_PATTERN = re.compile(r":\d+")


def find_files(source_dir: Path) -> list[Path]:
    files = []
    for path in source_dir.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix in SKIP_EXTENSIONS:
            continue
        if any(path.name.startswith(pfx) for pfx in SKIP_NAME_PREFIXES):
            continue
        files.append(path)
    return files


def check_service(name: str, svc: dict, services: dict) -> list[str]:
    allowed_ports: set[int] = {svc["port"]}
    for dep in svc.get("may_call", []):
        allowed_ports.add(services[dep]["port"])
    # cors_from ports may appear in source as CORS AllowedOrigin — not an outbound call
    for dep in svc.get("cors_from", []):
        allowed_ports.add(services[dep]["port"])

    forbidden: dict[int, str] = {
        cfg["port"]: dep_name
        for dep_name, cfg in services.items()
        if cfg["port"] not in allowed_ports
    }
    if not forbidden:
        return []

    root = Path(__file__).parent.parent
    source_dir = root / svc["source_dir"]
    if not source_dir.exists():
        return []

    violations = []
    for file in find_files(source_dir):
        try:
            text = file.read_text(errors="ignore")
        except OSError:
            continue

        for lineno, line in enumerate(text.splitlines(), start=1):
            for match in PORT_PATTERN.finditer(line):
                port_str = match.group()[1:]  # strip the leading colon
                try:
                    port = int(port_str)
                except ValueError:
                    continue
                if port in forbidden:
                    rel_file = file.relative_to(root)
                    forbidden_svc = forbidden[port]
                    violations.append(
                        f"  [{name}] → [{forbidden_svc}] forbidden  "
                        f"{rel_file}:{lineno}  {line.strip()}"
                    )

    return violations


def main() -> int:
    root = Path(__file__).parent.parent
    deps_file = root / "deps.yaml"
    if not deps_file.exists():
        print(f"ERROR: {deps_file} not found", file=sys.stderr)
        return 2

    config = yaml.safe_load(deps_file.read_text())
    services: dict = config["services"]

    all_violations: list[str] = []
    for name, svc in services.items():
        all_violations.extend(check_service(name, svc, services))

    if all_violations:
        print("❌  Dependency violations found:\n")
        for v in all_violations:
            print(v)
        print(
            f"\n{len(all_violations)} violation(s). "
            "See ARCHITECTURE.md for allowed call directions."
        )
        return 1

    print(f"✅  All dependency rules satisfied ({len(services)} services checked).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
