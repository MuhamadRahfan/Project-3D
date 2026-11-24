import glob
import os

cfg_dir = os.path.expanduser("~/.config/godot")
os.makedirs(cfg_dir, exist_ok=True)
files = sorted(glob.glob(os.path.join(cfg_dir, "editor_settings-*.tres")))
target = files[0] if files else os.path.join(cfg_dir, "editor_settings-4.7.tres")

content = (
    open(target, "r", encoding="utf-8").read()
    if os.path.exists(target)
    else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
)

updates = {
    "export/android/android_sdk_path": f'"{os.environ["ANDROID_HOME"]}"',
    "export/android/java_sdk_path": f'"{os.environ["JAVA_HOME"]}"',
    "export/android/debug_keystore": f'"{os.environ["GITHUB_WORKSPACE"]}/android/debug.keystore"',
    "export/android/debug_keystore_user": '"androiddebugkey"',
    "export/android/debug_keystore_pass": '"android"',
}

lines = content.splitlines()
existing = set()
out = []
for line in lines:
    replaced = False
    for k, v in updates.items():
        if line.startswith(k + " =") or line.startswith(k + "="):
            out.append(f"{k} = {v}")
            existing.add(k)
            replaced = True
            break
    if not replaced:
        out.append(line)

for k, v in updates.items():
    if k not in existing:
        out.append(f"{k} = {v}")

with open(target, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")

print("Updated EditorSettings:", target)
