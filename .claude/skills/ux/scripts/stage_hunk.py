"""Stage only this session's change to a file another session also edited: HEAD's content with the
same replacement applied, written to the index. The working tree is left as it is.
Run from the repo root:
    python -X utf8 .claude/skills/ux/scripts/stage_hunk.py <repo-relative path> <old block file> <new block file>
<old block file> holds the lines as HEAD has them, <new block file> as they should be committed.
"""
import subprocess
import sys
from pathlib import Path

path, old_file, new_file = sys.argv[1:4]
head = subprocess.run(["git", "show", f"HEAD:{path}"], capture_output=True, check=True).stdout
crlf = b"\r\n" in head
old = Path(old_file).read_bytes().replace(b"\r\n", b"\n")
new = Path(new_file).read_bytes().replace(b"\r\n", b"\n")
if crlf:
    old, new = old.replace(b"\n", b"\r\n"), new.replace(b"\n", b"\r\n")
if head.count(old) != 1:
    raise SystemExit(f"The old block appears {head.count(old)} times in HEAD's {path}; nothing staged.")
staged = head.replace(old, new)
blob = subprocess.run(["git", "hash-object", "-w", "--stdin"], input=staged, capture_output=True,
                      check=True).stdout.decode().strip()
mode = subprocess.run(["git", "ls-files", "-s", path], capture_output=True, check=True).stdout.decode().split()[0]
subprocess.run(["git", "update-index", "--cacheinfo", f"{mode},{blob},{path}"], check=True)
print("staged", path, "as", blob[:10])
