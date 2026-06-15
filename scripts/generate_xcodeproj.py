#!/usr/bin/env python3
"""
Generates Musicarr.xcodeproj (project.pbxproj) with two application targets that
share the same SwiftUI sources:

  * Musicarr        — iOS (iPhone / iPad)
  * Musicarr-tvOS   — tvOS (Apple TV)

This keeps the project openable in Xcode without requiring XcodeGen. Re-run after
adding or removing source files:

    python3 scripts/generate_xcodeproj.py

The canonical structure also lives in project.yml (XcodeGen) for those who prefer
that tool; both describe the same project.
"""

import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = "Musicarr"

def oid(*parts):
    """Deterministic 24-hex object id from a salt, so regeneration is stable."""
    h = hashlib.md5(("::".join(parts)).encode()).hexdigest().upper()
    return h[:24]

def find_sources():
    swift, assets = [], []
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, SRC_DIR)):
        rel_dir = os.path.relpath(dirpath, ROOT)
        if ".xcassets" in rel_dir:
            # add the catalog as a single resource, don't descend into it
            continue
        for f in sorted(files):
            rel = os.path.join(rel_dir, f)
            if f.endswith(".swift"):
                swift.append(rel)
        for d in sorted(_dirs):
            if d.endswith(".xcassets"):
                assets.append(os.path.join(rel_dir, d))
    return sorted(swift), sorted(assets)

SWIFT, ASSETS = find_sources()

# ---- File references -------------------------------------------------------

file_refs = {}   # path -> fileRef id
def file_ref(path, ftype, name=None):
    fid = oid("fileref", path)
    file_refs[path] = fid
    nm = name or os.path.basename(path)
    return f'\t\t{fid} /* {nm} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{os.path.basename(path)}"; sourceTree = "<group>"; }};'

def asset_ref(path):
    fid = oid("fileref", path)
    file_refs[path] = fid
    return f'\t\t{fid} /* {os.path.basename(path)} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "{os.path.basename(path)}"; sourceTree = "<group>"; }};'

frefs = []
for s in SWIFT:
    frefs.append(file_ref(s, "sourcecode.swift"))
for a in ASSETS:
    frefs.append(asset_ref(a))
# Info.plists
plist_ios = "Musicarr/Resources/Info-iOS.plist"
plist_tv = "Musicarr/Resources/Info-tvOS.plist"
frefs.append(file_ref(plist_ios, "text.plist.xml"))
frefs.append(file_ref(plist_tv, "text.plist.xml"))

# product refs
prod_ios = oid("product", "ios")
prod_tv = oid("product", "tvos")
frefs.append(f'\t\t{prod_ios} /* Musicarr.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Musicarr.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
frefs.append(f'\t\t{prod_tv} /* Musicarr-tvOS.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "Musicarr-tvOS.app"; sourceTree = BUILT_PRODUCTS_DIR; }};')

# ---- Build files (per target) ---------------------------------------------

def build_files(prefix):
    """Returns (entries, source_ids, resource_ids) for one target."""
    entries, src_ids, res_ids = [], [], []
    for s in SWIFT:
        bid = oid("buildfile", prefix, s)
        entries.append(f'\t\t{bid} /* {os.path.basename(s)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[s]} /* {os.path.basename(s)} */; }};')
        src_ids.append((bid, os.path.basename(s)))
    for a in ASSETS:
        bid = oid("buildfile", prefix, a)
        entries.append(f'\t\t{bid} /* {os.path.basename(a)} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs[a]} /* {os.path.basename(a)} */; }};')
        res_ids.append((bid, os.path.basename(a)))
    return entries, src_ids, res_ids

bf_ios, src_ios, res_ios = build_files("ios")
bf_tv, src_tv, res_tv = build_files("tvos")

# ---- Groups (mirror the folder tree) --------------------------------------

# Build a nested group structure from the swift + asset + plist paths.
tree = {}
def insert(path):
    parts = path.split(os.sep)
    node = tree
    for p in parts[:-1]:
        node = node.setdefault(p, {})
    node.setdefault("__files__", []).append(path)

for p in SWIFT + ASSETS + [plist_ios, plist_tv]:
    insert(p)

group_defs = []
def emit_group(name, node, salt):
    gid = oid("group", salt)
    children = []
    for key in sorted(k for k in node if k != "__files__"):
        child_id, _ = emit_group(key, node[key], salt + "/" + key)
        children.append((child_id, key))
    for f in sorted(node.get("__files__", [])):
        children.append((file_refs[f], os.path.basename(f)))
    lines = [f'\t\t{gid} /* {name} */ = {{',
             '\t\t\tisa = PBXGroup;',
             '\t\t\tchildren = (']
    for cid, cname in children:
        lines.append(f'\t\t\t\t{cid} /* {cname} */,')
    lines.append('\t\t\t);')
    lines.append(f'\t\t\tpath = "{name}";' if name != "__ROOT__" else '\t\t\tsourceTree = "<group>";')
    if name != "__ROOT__":
        lines.append('\t\t\tsourceTree = "<group>";')
    lines.append('\t\t};')
    group_defs.append("\n".join(lines))
    return gid, name

# The Musicarr source group sits under the main group along with Products.
musicarr_group_id, _ = emit_group(SRC_DIR, tree.get(SRC_DIR, {}), SRC_DIR)

products_group = oid("group", "Products")
group_defs.append(
    f'\t\t{products_group} /* Products */ = {{\n'
    '\t\t\tisa = PBXGroup;\n'
    '\t\t\tchildren = (\n'
    f'\t\t\t\t{prod_ios} /* Musicarr.app */,\n'
    f'\t\t\t\t{prod_tv} /* Musicarr-tvOS.app */,\n'
    '\t\t\t);\n'
    '\t\t\tname = Products;\n'
    '\t\t\tsourceTree = "<group>";\n'
    '\t\t};'
)

main_group = oid("group", "main")
group_defs.append(
    f'\t\t{main_group} = {{\n'
    '\t\t\tisa = PBXGroup;\n'
    '\t\t\tchildren = (\n'
    f'\t\t\t\t{musicarr_group_id} /* Musicarr */,\n'
    f'\t\t\t\t{products_group} /* Products */,\n'
    '\t\t\t);\n'
    '\t\t\tsourceTree = "<group>";\n'
    '\t\t};'
)

# ---- Build phases ----------------------------------------------------------

def sources_phase(salt, ids):
    pid = oid("sources", salt)
    lines = [f'\t\t{pid} /* Sources */ = {{',
             '\t\t\tisa = PBXSourcesBuildPhase;',
             '\t\t\tbuildActionMask = 2147483647;',
             '\t\t\tfiles = (']
    for bid, nm in ids:
        lines.append(f'\t\t\t\t{bid} /* {nm} in Sources */,')
    lines += ['\t\t\t);', '\t\t\trunOnlyForDeploymentPostprocessing = 0;', '\t\t};']
    return pid, "\n".join(lines)

def resources_phase(salt, ids):
    pid = oid("resources", salt)
    lines = [f'\t\t{pid} /* Resources */ = {{',
             '\t\t\tisa = PBXResourcesBuildPhase;',
             '\t\t\tbuildActionMask = 2147483647;',
             '\t\t\tfiles = (']
    for bid, nm in ids:
        lines.append(f'\t\t\t\t{bid} /* {nm} in Resources */,')
    lines += ['\t\t\t);', '\t\t\trunOnlyForDeploymentPostprocessing = 0;', '\t\t};']
    return pid, "\n".join(lines)

def frameworks_phase(salt):
    pid = oid("frameworks", salt)
    return pid, (f'\t\t{pid} /* Frameworks */ = {{\n'
                 '\t\t\tisa = PBXFrameworksBuildPhase;\n'
                 '\t\t\tbuildActionMask = 2147483647;\n'
                 '\t\t\tfiles = (\n\t\t\t);\n'
                 '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};')

src_ios_id, src_ios_phase = sources_phase("ios", src_ios)
src_tv_id, src_tv_phase = sources_phase("tvos", src_tv)
res_ios_id, res_ios_phase = resources_phase("ios", res_ios)
res_tv_id, res_tv_phase = resources_phase("tvos", res_tv)
fw_ios_id, fw_ios_phase = frameworks_phase("ios")
fw_tv_id, fw_tv_phase = frameworks_phase("tvos")

# ---- Build configurations --------------------------------------------------

def project_common():
    return {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "SWIFT_VERSION": "5.0",
        "MARKETING_VERSION": "1.0",
        "CURRENT_PROJECT_VERSION": "1",
    }

def fmt_settings(d):
    out = []
    for k in sorted(d):
        v = d[k]
        if isinstance(v, list):
            out.append(f'\t\t\t\t{k} = (')
            for item in v:
                out.append(f'\t\t\t\t\t"{item}",')
            out.append('\t\t\t\t);')
        else:
            out.append(f'\t\t\t\t{k} = {v};')
    return "\n".join(out)

def xcconfig(salt, name, settings):
    cid = oid("xcbc", salt, name)
    block = (f'\t\t{cid} /* {name} */ = {{\n'
             '\t\t\tisa = XCBuildConfiguration;\n'
             '\t\t\tbuildSettings = {\n'
             f'{fmt_settings(settings)}\n'
             '\t\t\t};\n'
             f'\t\t\tname = {name};\n'
             '\t\t};')
    return cid, block

def xcconfiglist(salt, debug_id, release_id, owner):
    lid = oid("xccl", salt)
    block = (f'\t\t{lid} /* Build configuration list for {owner} */ = {{\n'
             '\t\t\tisa = XCConfigurationList;\n'
             '\t\t\tbuildConfigurations = (\n'
             f'\t\t\t\t{debug_id} /* Debug */,\n'
             f'\t\t\t\t{release_id} /* Release */,\n'
             '\t\t\t);\n'
             '\t\t\tdefaultConfigurationIsVisible = 0;\n'
             '\t\t\tdefaultConfigurationName = Release;\n'
             '\t\t};')
    return lid, block

cfg_blocks = []
cfglist_blocks = []

# Project-level Debug/Release
proj_debug = project_common(); proj_debug.update({"ENABLE_TESTABILITY": "YES", "ONLY_ACTIVE_ARCH": "YES", "DEBUG_INFORMATION_FORMAT": "dwarf", "GCC_OPTIMIZATION_LEVEL": "0", "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"', "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"})
proj_release = project_common(); proj_release.update({"DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"', "SWIFT_OPTIMIZATION_LEVEL": '"-O"', "VALIDATE_PRODUCT": "YES", "ENABLE_NS_ASSERTIONS": "NO"})
pd_id, b = xcconfig("proj", "Debug", proj_debug); cfg_blocks.append(b)
pr_id, b = xcconfig("proj", "Release", proj_release); cfg_blocks.append(b)
proj_list, b = xcconfiglist("proj", pd_id, pr_id, 'PBXProject "Musicarr"'); cfglist_blocks.append(b)

def target_settings(platform, bundle_id, plist, family, appicon):
    s = {
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": f'"{plist}"',
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_id,
        "PRODUCT_NAME": '"$(TARGET_NAME)"',
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "TARGETED_DEVICE_FAMILY": f'"{family}"',
        "SWIFT_VERSION": "5.0",
    }
    if appicon:
        s["ASSETCATALOG_COMPILER_APPICON_NAME"] = appicon
    if platform == "ios":
        s["SDKROOT"] = "iphoneos"
        s["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"
        s["SUPPORTED_PLATFORMS"] = '"iphoneos iphonesimulator"'
        s["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
    else:
        s["SDKROOT"] = "appletvos"
        s["TVOS_DEPLOYMENT_TARGET"] = "16.0"
        s["SUPPORTED_PLATFORMS"] = '"appletvos appletvsimulator"'
    return s

# iOS target configs
ios_d = target_settings("ios", "ovh.bigbossben.musicarr", plist_ios, "1,2", "AppIcon")
ios_r = dict(ios_d)
id_id, b = xcconfig("tios", "Debug", ios_d); cfg_blocks.append(b)
ir_id, b = xcconfig("tios", "Release", ios_r); cfg_blocks.append(b)
ios_list, b = xcconfiglist("tios", id_id, ir_id, 'PBXNativeTarget "Musicarr"'); cfglist_blocks.append(b)

# tvOS target configs
tv_d = target_settings("tvos", "ovh.bigbossben.musicarr.tv", plist_tv, "3", None)
tv_r = dict(tv_d)
td_id, b = xcconfig("ttv", "Debug", tv_d); cfg_blocks.append(b)
tr_id, b = xcconfig("ttv", "Release", tv_r); cfg_blocks.append(b)
tv_list, b = xcconfiglist("ttv", td_id, tr_id, 'PBXNativeTarget "Musicarr-tvOS"'); cfglist_blocks.append(b)

# ---- Native targets --------------------------------------------------------

target_ios = oid("target", "ios")
target_tv = oid("target", "tvos")

def native_target(tid, name, cfglist, src_phase, fw_phase, res_phase, product_id, product_name):
    return (f'\t\t{tid} /* {name} */ = {{\n'
            '\t\t\tisa = PBXNativeTarget;\n'
            f'\t\t\tbuildConfigurationList = {cfglist} /* Build configuration list for PBXNativeTarget "{name}" */;\n'
            '\t\t\tbuildPhases = (\n'
            f'\t\t\t\t{src_phase} /* Sources */,\n'
            f'\t\t\t\t{fw_phase} /* Frameworks */,\n'
            f'\t\t\t\t{res_phase} /* Resources */,\n'
            '\t\t\t);\n'
            '\t\t\tbuildRules = (\n\t\t\t);\n'
            '\t\t\tdependencies = (\n\t\t\t);\n'
            f'\t\t\tname = "{name}";\n'
            f'\t\t\tproductName = "{name}";\n'
            f'\t\t\tproductReference = {product_id} /* {product_name} */;\n'
            '\t\t\tproductType = "com.apple.product-type.application";\n'
            '\t\t};')

nt_ios = native_target(target_ios, "Musicarr", ios_list, src_ios_id, fw_ios_id, res_ios_id, prod_ios, "Musicarr.app")
nt_tv = native_target(target_tv, "Musicarr-tvOS", tv_list, src_tv_id, fw_tv_id, res_tv_id, prod_tv, "Musicarr-tvOS.app")

# ---- Project object --------------------------------------------------------

project_id = oid("project", "root")
project_obj = (f'\t\t{project_id} /* Project object */ = {{\n'
               '\t\t\tisa = PBXProject;\n'
               '\t\t\tattributes = {\n'
               '\t\t\t\tBuildIndependentTargetsInParallel = 1;\n'
               '\t\t\t\tLastSwiftUpdateCheck = 1520;\n'
               '\t\t\t\tLastUpgradeCheck = 1520;\n'
               '\t\t\t\tTargetAttributes = {\n'
               f'\t\t\t\t\t{target_ios} = {{CreatedOnToolsVersion = 15.2;}};\n'
               f'\t\t\t\t\t{target_tv} = {{CreatedOnToolsVersion = 15.2;}};\n'
               '\t\t\t\t};\n'
               '\t\t\t};\n'
               f'\t\t\tbuildConfigurationList = {proj_list} /* Build configuration list for PBXProject "Musicarr" */;\n'
               '\t\t\tcompatibilityVersion = "Xcode 14.0";\n'
               '\t\t\tdevelopmentRegion = en;\n'
               '\t\t\thasScannedForEncodings = 0;\n'
               '\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n'
               f'\t\t\tmainGroup = {main_group};\n'
               f'\t\t\tproductRefGroup = {products_group} /* Products */;\n'
               '\t\t\tprojectDirPath = "";\n'
               '\t\t\tprojectRoot = "";\n'
               '\t\t\ttargets = (\n'
               f'\t\t\t\t{target_ios} /* Musicarr */,\n'
               f'\t\t\t\t{target_tv} /* Musicarr-tvOS */,\n'
               '\t\t\t);\n'
               '\t\t};')

# ---- Assemble --------------------------------------------------------------

def section(name, body):
    return f'/* Begin {name} section */\n{body}\n/* End {name} section */\n'

out = ['// !$*UTF8*$!', '{',
       '\tarchiveVersion = 1;',
       '\tclasses = {',
       '\t};',
       '\tobjectVersion = 56;',
       '\tobjects = {',
       '']

out.append(section("PBXBuildFile", "\n".join(bf_ios + bf_tv)))
out.append(section("PBXFileReference", "\n".join(frefs)))
out.append(section("PBXFrameworksBuildPhase", "\n".join([fw_ios_phase, fw_tv_phase])))
out.append(section("PBXGroup", "\n".join(group_defs)))
out.append(section("PBXNativeTarget", "\n".join([nt_ios, nt_tv])))
out.append(section("PBXProject", project_obj))
out.append(section("PBXResourcesBuildPhase", "\n".join([res_ios_phase, res_tv_phase])))
out.append(section("PBXSourcesBuildPhase", "\n".join([src_ios_phase, src_tv_phase])))
out.append(section("XCBuildConfiguration", "\n".join(cfg_blocks)))
out.append(section("XCConfigurationList", "\n".join(cfglist_blocks)))

out.append(f'\t}};\n\trootObject = {project_id} /* Project object */;\n}}')

pbxproj = "\n".join(out) + "\n"

proj_dir = os.path.join(ROOT, "Musicarr.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write(pbxproj)

print(f"Wrote {proj_dir}/project.pbxproj")
print(f"  {len(SWIFT)} Swift files, {len(ASSETS)} asset catalog(s), 2 targets")
