#!/usr/bin/env python3
"""Turn the .deb files built from a distro's gtk+2.0 packaging into the gtk2-ng
(or gtk2-king) packages: renamed, replacing the distro's, plus the metapackage.

  ngify.py --flavor ng --stock-ver 2.24.33-2ubuntu2.1 --out DIR a.deb b.deb ...

For each package: Package gets the new name; Provides, Conflicts and Replaces
list the distro's name(s) (Provides with the distro's exact version, so that
`libgtk2.0-0 (= 2.24.33-2ubuntu2.1)` in the distro's own packages is still met);
the dependencies on the other packages of the set follow the new names. The
shlibs/symbols files are left as they are on purpose: they name the distro's
package, so a program built against gtk2-ng can be installed with either.
`king` is the same set again (libgtk2-king-0, ...) and also provides, conflicts
with and replaces the `ng` names.
"""
import argparse, os, re, shutil, subprocess, sys, tempfile

# distro name(s) -> new name template (@F@ = ng or king). A library has two
# distro names, because Debian 13, Ubuntu 24.04 and 26.04 have the t64 one.
PACKAGES = [
    (["libgtk2.0-0", "libgtk2.0-0t64"], "libgtk2-@F@-0"),
    (["libgtk2.0-common"],              "libgtk2-@F@-common"),
    (["libgtk2.0-bin"],                 "libgtk2-@F@-bin"),
    (["libgtk2.0-dev"],                 "libgtk2-@F@-dev"),
    (["gtk2-engines-pixbuf"],           "gtk2-@F@-engines-pixbuf"),
    (["libgail18", "libgail18t64"],     "libgail-@F@-18"),
    (["libgail-common"],                "libgail-@F@-common"),
    (["libgail-dev"],                   "libgail-@F@-dev"),
    (["gir1.2-gtk-2.0"],                "gir1.2-gtk-2.0-@F@"),
    (["gtk2.0-examples"],               "gtk2-@F@-examples"),
]
DEP_FIELDS = ["Depends", "Pre-Depends", "Recommends", "Suggests", "Breaks", "Conflicts",
              "Replaces", "Enhances"]
# what the metapackage pulls in; the rest is suggested
META_RUNTIME = ["libgtk2.0-0", "libgtk2.0-common", "libgtk2.0-bin", "gtk2-engines-pixbuf",
                "libgail18", "libgail-common"]
MAINTAINER = "Kiyoshi Spreclerg <kiyoshi_pip@protonmail.com>"


def parse(text):
    fields, cur = [], None
    for line in text.rstrip("\n").split("\n"):
        if line[:1] in (" ", "\t") and cur is not None:
            cur[1].append(line)
        else:
            name, _, val = line.partition(":")
            cur = [name, [val.strip()]]
            fields.append(cur)
    return fields


def dump(fields):
    out = []
    for name, lines in fields:
        out.append("%s: %s" % (name, lines[0]))
        out.extend(lines[1:])
    return "\n".join(out) + "\n"


def get(fields, name):
    for f in fields:
        if f[0].lower() == name.lower():
            return "\n".join(f[1])
    return None


def put(fields, name, value, after=None):
    for f in fields:
        if f[0].lower() == name.lower():
            f[1] = value.split("\n")
            return
    new = [name, value.split("\n")]
    if after:
        for i, f in enumerate(fields):
            if f[0].lower() == after.lower():
                fields.insert(i + 1, new)
                return
    fields.append(new)


def split_deps(value):
    return [d.strip() for d in re.split(r",\s*", value.replace("\n", " ")) if d.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flavor", choices=["ng", "king"], default="ng")
    ap.add_argument("--stock-ver", required=True, help="version of the distro's gtk+2.0 packages")
    ap.add_argument("--commit", default="", help="gtk2-ng commit the packages were built from")
    ap.add_argument("--out", required=True)
    ap.add_argument("debs", nargs="+")
    a = ap.parse_args()
    F = a.flavor
    os.makedirs(a.out, exist_ok=True)

    def newname(tmpl, flavor=F):
        return tmpl.replace("@F@", flavor)

    # distro name -> our name, for the dependency rewrite
    rename = {}
    for old, tmpl in PACKAGES:
        for o in old:
            rename[o] = newname(tmpl)

    built = {}   # our name -> (old names, version, control fields)
    work = tempfile.mkdtemp()
    for deb in a.debs:
        if "dbgsym" in os.path.basename(deb):
            continue
        d = os.path.join(work, os.path.basename(deb)[:-4])
        subprocess.check_call(["dpkg-deb", "-R", deb, d])
        cpath = os.path.join(d, "DEBIAN", "control")
        fields = parse(open(cpath).read())
        pkg = get(fields, "Package")
        if pkg not in rename:
            print("ngify: skipping %s (not a GTK2 package we replace)" % pkg)
            shutil.rmtree(d)
            continue
        entry = next(e for e in PACKAGES if pkg in e[0])
        old_names, tmpl = entry
        new = newname(tmpl)
        version = get(fields, "Version")

        # dependencies on packages of the set follow the new names
        for fld in DEP_FIELDS:
            val = get(fields, fld)
            if val is None:
                continue
            out = []
            for dep in split_deps(val):
                alts = []
                for alt in dep.split("|"):
                    alt = alt.strip()
                    m = re.match(r"^([a-z0-9][a-z0-9+.\-]*)(:[a-z0-9\-]+)?(.*)$", alt)
                    name = m.group(1)
                    alts.append(rename.get(name, name) + (m.group(2) or "") + m.group(3))
                out.append(" | ".join(alts))
            put(fields, fld, ", ".join(out))

        # The pixbuf engine plugs into GTK but the distro's package has no dependency on the
        # library (its shlibdeps leaves it out), so nothing would remove ours when the distro's
        # library comes back: make it depend on our library, and it leaves with it
        if "gtk2-engines-pixbuf" in old_names:
            cur = split_deps(get(fields, "Depends") or "")
            put(fields, "Depends", ", ".join(cur + ["libgtk2-%s-0 (= %s)" % (F, version)]))

        # replaces the distro's package (and, for king, the ng one)
        stock = list(old_names)
        others = [newname(tmpl, "ng")] if F == "king" else []
        provides = split_deps(get(fields, "Provides") or "")
        provides += ["%s (= %s)" % (n, a.stock_ver) for n in stock]
        provides += ["%s (= %s)" % (n, version) for n in others]
        put(fields, "Provides", ", ".join(provides), after="Depends")
        for fld in ("Conflicts", "Replaces"):
            cur = split_deps(get(fields, fld) or "")
            put(fields, fld, ", ".join(cur + stock + others), after="Provides")

        put(fields, "Package", new)
        put(fields, "Source", "gtk2-" + F)
        put(fields, "Maintainer", MAINTAINER)
        desc = get(fields, "Description").split("\n")
        desc[0] += " (gtk2-%s)" % F
        desc += [" .",
                 " This is the gtk2-%s build: a drop-in replacement for the distro's" % F,
                 " package of the same library, with the same ABI. It conflicts with it,",
                 " and installing the distro's package again switches back."]
        if a.commit:
            put(fields, "X-Gtk2ng-Commit", a.commit)
        put(fields, "Description", "\n".join(desc))
        open(cpath, "w").write(dump(fields))

        outname = "%s_%s_%s.deb" % (new, version.replace(":", "%3a"), get(fields, "Architecture"))
        subprocess.check_call(["dpkg-deb", "--root-owner-group", "-b", d, os.path.join(a.out, outname)],
                              stdout=subprocess.DEVNULL)
        built[new] = (old_names, version, fields)
        shutil.rmtree(d)
        print("ngify: %s -> %s" % (pkg, outname))

    if not built:
        sys.exit("ngify: no package to convert")

    # The metapackage: one name to install. It has NO Conflicts with the distro's names: the
    # libraries provide those names, and a package that conflicts with a name another package
    # provides makes apt refuse the pair (the libraries carry the Conflicts/Replaces that swap
    # the distro's packages). Installing the distro's library again removes the libraries and,
    # because it depends on them, the metapackage too.
    version = next(iter(built.values()))[1]
    meta = "gtk2-" + F
    present = {}
    for n, (old, _v, _f) in built.items():
        for o in old:
            present[o] = n
    runtime = sorted({n for n, (old, _v, _f) in built.items() if any(o in META_RUNTIME for o in old)})
    gir = sorted(n for n, (old, _v, _f) in built.items() if "gir1.2-gtk-2.0" in old)
    suggests = sorted(n for n, (old, _v, _f) in built.items()
                      if any(o in ("libgtk2.0-dev", "libgail-dev", "gtk2.0-examples") for o in old))
    md = os.path.join(work, meta, "DEBIAN")
    os.makedirs(md)
    c = [("Package", meta), ("Source", meta), ("Version", version), ("Architecture", "all"), ("Section", "libs"),
         ("Priority", "optional"), ("Maintainer", MAINTAINER),
         ("Depends", ", ".join("%s (= %s)" % (n, version) for n in runtime)),
         ("Recommends", ", ".join("%s (= %s)" % (n, version) for n in gir)),
         ("Suggests", ", ".join(suggests)),
         ("Conflicts", "gtk2-ng" if F == "king" else ""),
         ("Provides", "gtk2-ng" if F == "king" else ""),
         ("Replaces", "gtk2-ng" if F == "king" else "")]
    text = "".join("%s: %s\n" % (k, v) for k, v in c if v)
    text += ("Description: GTK2 %s: drop-in replacement for the distro's GTK2 libraries\n"
             " Installs the gtk2-%s libraries in place of the distro's GTK2. Applications\n"
             " that depend on the distro's package names keep working, because the\n"
             " gtk2-%s packages provide them. Installing the distro's libgtk2.0 again\n"
             " removes them and this package, and goes back to the distro's GTK2.\n") % (F, F, F)
    open(os.path.join(md, "control"), "w").write(text)
    outname = "%s_%s_all.deb" % (meta, version.replace(":", "%3a"))
    subprocess.check_call(["dpkg-deb", "--root-owner-group", "-b", os.path.dirname(md),
                           os.path.join(a.out, outname)], stdout=subprocess.DEVNULL)
    print("ngify: metapackage %s" % outname)
    shutil.rmtree(work)


main()
