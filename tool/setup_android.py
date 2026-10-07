#!/usr/bin/env python3
"""
Pasang file Android Infinity (notifikasi, biometrik, catat otomatis, widget)
ke proyek hasil `flutter create`.

Jalankan dari ROOT proyek Flutter:
    python3 tool/setup_android.py

Aman dijalankan berulang kali.
"""
import os
import re
import shutil
import sys

ROOT = os.getcwd()
HERE = os.path.dirname(os.path.abspath(__file__))
OVERLAY = os.path.normpath(os.path.join(HERE, "..", "android_overlay"))
APP = os.path.join(ROOT, "android", "app")
OVERLAY_PKG = "com.jose.infinity"
MIN_AGP = (8, 11, 1)


def fail(msg):
    print("GAGAL:", msg)
    sys.exit(1)


def info(msg):
    print("  -", msg)


if not os.path.isdir(OVERLAY):
    fail("Folder android_overlay tidak ditemukan di sebelah folder tool/.")
if not os.path.isdir(APP):
    fail("Folder android/app tidak ada. Jalankan dari root proyek Flutter (hasil flutter create).")

kts_path = os.path.join(APP, "build.gradle.kts")
groovy_path = os.path.join(APP, "build.gradle")
if os.path.exists(kts_path):
    gpath, kts = kts_path, True
elif os.path.exists(groovy_path):
    gpath, kts = groovy_path, False
else:
    fail("android/app/build.gradle(.kts) tidak ditemukan.")

print("Infinity: menyiapkan proyek Android")
g = open(gpath, encoding="utf-8").read()

# --- package name
m = re.search(r"namespace\s*=?\s*[\"']([\w.]+)[\"']", g)
if not m:
    fail("namespace tidak ditemukan di " + os.path.basename(gpath))
pkg = m.group(1)
info("package: " + pkg)

# --- desugaring (wajib untuk flutter_local_notifications)
if "oreLibraryDesugaringEnabled" not in g:
    line = "isCoreLibraryDesugaringEnabled = true" if kts else "coreLibraryDesugaringEnabled true"
    g, n = re.subn(r"compileOptions\s*\{", "compileOptions {\n        " + line, g, count=1)
    if n == 0:
        fail("blok compileOptions tidak ditemukan")
    info("desugaring diaktifkan")

# --- minSdk 24 (local_auth) + multidex
if kts:
    g, n = re.subn(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", g, count=1)
else:
    g, n = re.subn(r"minSdk(?:Version)?\s+[^\n]+", "minSdkVersion 24", g, count=1)
if n == 0:
    fail("baris minSdk tidak ditemukan")
if "multiDexEnabled" not in g:
    if kts:
        g = g.replace("minSdk = 24", "minSdk = 24\n        multiDexEnabled = true", 1)
    else:
        g = g.replace("minSdkVersion 24", "minSdkVersion 24\n        multiDexEnabled true", 1)
info("minSdk = 24, multidex aktif")
# --- kunci tanda tangan tetap dari env INFINITY_KEYSTORE (supaya update tidak hapus data)
if "INFINITY_KEYSTORE" not in g:
    if kts:
        block = ('signingConfigs {\n'
                 '        getByName("debug") {\n'
                 '            val ks = System.getenv("INFINITY_KEYSTORE")\n'
                 '            if (ks != null && file(ks).exists()) {\n'
                 '                storeFile = file(ks)\n'
                 '                storePassword = "android"\n'
                 '                keyAlias = "androiddebugkey"\n'
                 '                keyPassword = "android"\n'
                 '            }\n'
                 '        }\n'
                 '    }\n\n    buildTypes {')
    else:
        block = ('signingConfigs {\n'
                 '        debug {\n'
                 '            def ks = System.getenv("INFINITY_KEYSTORE")\n'
                 '            if (ks != null && file(ks).exists()) {\n'
                 '                storeFile file(ks)\n'
                 '                storePassword "android"\n'
                 '                keyAlias "androiddebugkey"\n'
                 '                keyPassword "android"\n'
                 '            }\n'
                 '        }\n'
                 '    }\n\n    buildTypes {')
    g, n = re.subn(r"buildTypes\s*\{", block, g, count=1)
    if n == 0:
        fail("blok buildTypes tidak ditemukan")
    info("signing pakai INFINITY_KEYSTORE kalau ada")


# --- dependencies
if "desugar_jdk_libs" not in g:
    if kts:
        dep = ('\ndependencies {\n'
               '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
               '    implementation("androidx.appcompat:appcompat:1.7.0")\n'
               '}\n')
    else:
        dep = ("\ndependencies {\n"
               "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
               "    implementation 'androidx.appcompat:appcompat:1.7.0'\n"
               "}\n")
    g = g.rstrip("\n") + "\n" + dep
    info("dependency desugar_jdk_libs + appcompat ditambahkan")

open(gpath, "w", encoding="utf-8").write(g)

# --- salin file overlay
main_dir = os.path.join(APP, "src", "main")
kotlin_src = os.path.join("app", "src", "main", "kotlin", *OVERLAY_PKG.split("."))
kotlin_dst = os.path.join(main_dir, "kotlin", *pkg.split("."))

manifest_dst = os.path.join(main_dir, "AndroidManifest.xml")
if os.path.exists(manifest_dst) and not os.path.exists(manifest_dst + ".bak"):
    shutil.copy2(manifest_dst, manifest_dst + ".bak")

copied = 0
for root, _dirs, files in os.walk(OVERLAY):
    for f in files:
        src = os.path.join(root, f)
        rel = os.path.relpath(src, OVERLAY)
        if rel.startswith(kotlin_src + os.sep):
            dst = os.path.join(kotlin_dst, os.path.relpath(src, os.path.join(OVERLAY, kotlin_src)))
            text = open(src, encoding="utf-8").read()
            text = text.replace("package " + OVERLAY_PKG, "package " + pkg, 1)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            open(dst, "w", encoding="utf-8").write(text)
        else:
            dst = os.path.join(ROOT, "android", rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
        copied += 1
info("%d file disalin (manifest lama disimpan sebagai AndroidManifest.xml.bak)" % copied)

# --- buang MainActivity lain (mis. versi Java) supaya tidak dobel
keep = os.path.normpath(os.path.join(kotlin_dst, "MainActivity.kt"))
for base in ("kotlin", "java"):
    for root, _dirs, files in os.walk(os.path.join(main_dir, base)):
        for f in files:
            p = os.path.normpath(os.path.join(root, f))
            if f in ("MainActivity.kt", "MainActivity.java") and p != keep:
                os.remove(p)
                info("MainActivity lama dihapus: " + os.path.relpath(p, ROOT))

# --- cek versi Android Gradle Plugin
for name in ("settings.gradle.kts", "settings.gradle"):
    p = os.path.join(ROOT, "android", name)
    if os.path.exists(p):
        s = open(p, encoding="utf-8").read()
        mm = re.search(r"com\.android\.application[\"')\s]*version\s*[\"']([\d.]+)", s)
        if mm:
            ver = tuple(int(x) for x in mm.group(1).split(".")[:3])
            if ver < MIN_AGP:
                print("PERINGATAN: Android Gradle Plugin %s < 8.11.1 (syarat flutter_local_notifications v22)."
                      " Upgrade Flutter (flutter upgrade) lalu buat ulang proyek." % mm.group(1))
            else:
                info("Android Gradle Plugin " + mm.group(1) + " OK")
        break

print("Selesai. Lanjut: flutter build apk --release")
