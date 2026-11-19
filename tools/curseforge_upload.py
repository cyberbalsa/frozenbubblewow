#!/usr/bin/env python3
"""Upload a tested package to CurseForge's author API, without exposing credentials."""
import argparse
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request
import uuid
from zipfile import ZipFile

API = "https://wow.curseforge.com/api"


def request(path, token, data=None, content_type=None):
    headers = {"X-Api-Token": token, "User-Agent": "FrozenBubbleForever-release/1"}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(API + path, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        # Never dump request headers or token-bearing objects to CI logs.
        raise RuntimeError(f"CurseForge returned HTTP {exc.code} for {path}") from None
    except urllib.error.URLError:
        raise RuntimeError("Could not connect to CurseForge") from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--project-id", type=int, default=int(os.getenv("CF_PROJECT_ID", "1815958")))
    parser.add_argument("--game-version-id", type=int, default=int(os.getenv("CF_GAME_VERSION_ID", "17053")))
    parser.add_argument("--token-file", type=Path)
    parser.add_argument("--check", action="store_true", help="Validate authentication/version/package without uploading")
    args = parser.parse_args()
    token = args.token_file.read_text().strip() if args.token_file else os.getenv("CF_API_TOKEN", "").strip()
    if not token:
        raise RuntimeError("Set CF_API_TOKEN or pass --token-file")
    with ZipFile(args.archive) as archive:
        toc = archive.read("FrozenBubble/FrozenBubble.toc").decode()
    versions = request("/game/versions", token)
    version = next((v for v in versions if v["id"] == args.game_version_id), None)
    if not version or str(version.get("apiVersion")) != "16001" or "## Interface: 16001" not in toc:
        raise RuntimeError("Selected CurseForge game version does not match Forever interface 16001")
    print(f"Validated Forever {version['name']}; project {args.project_id}; {args.archive.name}")
    if args.check:
        return
    release_type = "alpha" if "alpha" in args.archive.name else "beta" if "beta" in args.archive.name else "release"
    changelog = Path("CHANGELOG.md").read_text()
    metadata = {"displayName": args.archive.stem, "gameVersions": [args.game_version_id],
                "releaseType": release_type, "changelog": changelog, "changelogType": "markdown"}
    boundary = "FrozenBubble" + uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n".encode()
            + json.dumps(metadata).encode()
            + f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{args.archive.name}\"\r\nContent-Type: application/zip\r\n\r\n".encode()
            + args.archive.read_bytes() + f"\r\n--{boundary}--\r\n".encode())
    result = request(f"/projects/{args.project_id}/upload-file", token, body,
                     f"multipart/form-data; boundary={boundary}")
    file_id = result.get("id")
    if not isinstance(file_id, int):
        raise RuntimeError("CurseForge did not return an uploaded file ID")
    print(f"CurseForge upload accepted: file {file_id}. Visibility depends on project/file review.")
    Path("dist/curseforge-result.json").write_text(json.dumps({"project": args.project_id, "file": file_id}))
    summary = os.getenv("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as f:
            f.write(f"CurseForge project **{args.project_id}**, uploaded file **{file_id}**.\n")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
