#!/usr/bin/env python3
"""Copies the FireSystem module files from a ma3-fire-system checkout into firesystem/:

    python3 tools/sync_firesystem.py ../ma3-fire-system

The tools are built from these copies, so a FireSystem fix reaches them only after a sync. It
also copies FireSystemIcons.lua (FS Icons' images, shipped in the release). It writes the checkout's commit into firesystem/SOURCE; run tools/make_tools.py afterwards.
"""
import os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_tools import MODULES


def main(argv):
    if len(argv) != 1:
        sys.exit(__doc__)
    src = os.path.abspath(argv[0])
    for m in MODULES:
        f = os.path.join(src, "plugins", "FireSystem%s.lua" % m)
        if not os.path.exists(f):
            sys.exit("not found: " + f)
        shutil.copyfile(f, os.path.join(ROOT, "firesystem", "FireSystem%s.lua" % m))
    # the icon pack FS Icons reads (shipped in the release, next to the tools)
    shutil.copyfile(os.path.join(src, "plugins", "FireSystemIcons.lua"), os.path.join(ROOT, "firesystem", "FireSystemIcons.lua"))
    rev = subprocess.run(["git", "-C", src, "log", "-1", "--format=%h %s"], capture_output=True, text=True).stdout.strip()
    open(os.path.join(ROOT, "firesystem", "SOURCE"), "w").write("ma3-fire-system " + (rev or "(unknown)") + "\n")
    print("copied %d modules from %s (%s)" % (len(MODULES), src, rev))


if __name__ == "__main__":
    main(sys.argv[1:])
