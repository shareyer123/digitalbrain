#!/usr/bin/env python3
"""
broadcast.py — push a standing notice into EVERY project's Context.md from one place.

Why this exists: the DigitalBrain chat is where machine-wide facts get discovered (ports, auth,
lockouts, conventions), but every other project has its own Context.md and nothing carried a fact
across. Hand-copying to six files drifts on the first edit.

Design rules, learned from this vault's own failures:
  * IDEMPOTENT + UPDATABLE. Blocks are fenced by an id. Re-running with the same id REPLACES the
    block rather than appending a second copy. Editing a notice is a re-broadcast, not a cleanup job.
  * A NO-OP CANNOT BE SILENT. Every project is reported as added / updated / unchanged / SKIPPED.
    (Kru's Brain layer sat with an un-ingested file for weeks because nothing said "I did nothing".)
  * NEVER TOUCH ## Current State. /end overwrites that section; anything written there dies.
    Blocks go directly under the H1, above everything.
  * ATOMIC WRITES. temp file + os.replace. A crash mid-write leaves the original intact.
    (A truncate-then-write destroyed a DevLog in this vault on 2026-08-31.)

Usage:
  python broadcast.py list
  python broadcast.py send    <id> <file-with-block.md> [--only P1,P2] [--dry-run]
  python broadcast.py remove  <id>                      [--only P1,P2] [--dry-run]
  python broadcast.py status  <id>
"""
import io
import os
import sys


def _brain_conf_vault():
    """VAULT from ~/.claude/brain.conf (written by install.sh). Exits loudly if not found."""
    f = os.path.join(os.path.expanduser("~"), ".claude", "brain.conf")
    try:
        for line in io.open(f, encoding="utf-8"):
            line = line.strip()
            if line.startswith("VAULT="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    sys.exit("broadcast.py: no VAULT. Set the VAULT env var or run install.sh to write ~/.claude/brain.conf")


VAULT = os.environ.get("VAULT") or _brain_conf_vault()
PROJECTS_DIR = os.path.join(VAULT, "Projects")


def marker(bid):
    return ("<!-- BROADCAST:%s -->" % bid, "<!-- /BROADCAST:%s -->" % bid)


def project_contexts(only=None):
    """Every Projects/*/Context.md. `only` filters by folder name."""
    out = []
    if not os.path.isdir(PROJECTS_DIR):
        return out
    for name in sorted(os.listdir(PROJECTS_DIR)):
        if only and name not in only:
            continue
        p = os.path.join(PROJECTS_DIR, name, "Context.md")
        if os.path.isfile(p):
            out.append((name, p))
    return out


def read(p):
    return io.open(p, encoding="utf-8").read()


def write_atomic(p, s):
    tmp = p + ".tmp"
    io.open(tmp, "w", encoding="utf-8", newline="").write(s)
    os.replace(tmp, p)


def find_anchor(s):
    """Insert point: end of the first H1 line. Returns index, or -1 if there is no H1."""
    for line in s.split("\n"):
        if line.startswith("# "):
            i = s.index(line) + len(line)
            return i
    return -1


def strip_block(s, bid):
    """Remove an existing fenced block. Returns (new_string, was_present)."""
    a, b = marker(bid)
    if a not in s or b not in s:
        return s, False
    start = s.index(a)
    end = s.index(b) + len(b)
    while end < len(s) and s[end] == "\n":
        end += 1
    while start > 0 and s[start - 1] == "\n":
        start -= 1
    # Restore a blank line, not a bare newline: a bare one makes each re-send eat
    # the separator before the next heading until the block fuses to it.
    return s[:start] + "\n\n" + s[end:], True


def cmd_send(bid, block_file, only, dry):
    if not os.path.isfile(block_file):
        print("ERROR: no such file: %s" % block_file)
        return 1
    body = read(block_file).strip("\n")
    a, b = marker(bid)
    fenced = "\n\n%s\n%s\n%s" % (a, body, b)

    targets = project_contexts(only)
    if not targets:
        print("ERROR: no Context.md files found (only=%s)" % (only,))
        return 1

    counts = {"added": 0, "updated": 0, "unchanged": 0, "skipped": 0}
    for name, path in targets:
        s = read(path)
        stripped, was = strip_block(s, bid)
        anchor = find_anchor(stripped)
        if anchor < 0:
            print("  SKIPPED  %-22s no H1 heading to anchor to" % name)
            counts["skipped"] += 1
            continue
        tail = stripped[anchor:]
        if not tail.startswith("\n\n"):
            tail = "\n\n" + tail.lstrip("\n")
        new = stripped[:anchor] + fenced + tail
        if new == s:
            print("  unchanged %-21s already current" % name)
            counts["unchanged"] += 1
            continue
        if not dry:
            write_atomic(path, new)
        verb = "updated" if was else "added"
        print("  %-9s %-21s %s" % (verb.upper(), name, "(dry run)" if dry else ""))
        counts[verb] += 1

    print("\n[%s] %d added, %d updated, %d unchanged, %d skipped%s"
          % (bid, counts["added"], counts["updated"], counts["unchanged"],
             counts["skipped"], "  (DRY RUN — nothing written)" if dry else ""))
    return 0


def cmd_remove(bid, only, dry):
    n = 0
    for name, path in project_contexts(only):
        s = read(path)
        new, was = strip_block(s, bid)
        if was:
            if not dry:
                write_atomic(path, new)
            print("  REMOVED  %s %s" % (name, "(dry run)" if dry else ""))
            n += 1
    print("\n[%s] removed from %d project(s)%s"
          % (bid, n, "  (DRY RUN)" if dry else ""))
    return 0


def cmd_status(bid):
    a, _ = marker(bid)
    present, absent = [], []
    for name, path in project_contexts():
        (present if a in read(path) else absent).append(name)
    print("[%s] present in %d: %s" % (bid, len(present), ", ".join(present) or "-"))
    print("[%s] ABSENT from %d: %s" % (bid, len(absent), ", ".join(absent) or "-"))
    return 0


def cmd_list():
    import re
    seen = {}
    for name, path in project_contexts():
        for bid in re.findall(r"<!-- BROADCAST:([^\s>]+) -->", read(path)):
            seen.setdefault(bid, []).append(name)
    if not seen:
        print("No broadcasts found in any Context.md.")
        return 0
    total = len(project_contexts())
    for bid, names in sorted(seen.items()):
        flag = "" if len(names) == total else "   <-- PARTIAL"
        print("  %-28s %d/%d  %s%s" % (bid, len(names), total, ", ".join(names), flag))
    return 0


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd = argv[1]
    only = None
    dry = "--dry-run" in argv
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))

    if cmd == "list":
        return cmd_list()
    if cmd == "status" and len(argv) >= 3:
        return cmd_status(argv[2])
    if cmd == "send" and len(argv) >= 4:
        return cmd_send(argv[2], argv[3], only, dry)
    if cmd == "remove" and len(argv) >= 3:
        return cmd_remove(argv[2], only, dry)
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
