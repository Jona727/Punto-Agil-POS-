import os
import re

def patch_bluetooth_serial():
    # Common locations for pub cache
    local_app_data = os.environ.get('LOCALAPPDATA', '')
    if not local_app_data:
        print("LOCALAPPDATA not found.")
        return

    pub_cache_path = os.path.join(local_app_data, 'Pub', 'Cache', 'hosted', 'pub.dev')
    
    # Find the flutter_bluetooth_serial package
    if not os.path.exists(pub_cache_path):
        print(f"Pub cache not found at {pub_cache_path}")
        return

    packages = [d for d in os.listdir(pub_cache_path) if d.startswith('flutter_bluetooth_serial-')]
    if not packages:
        print("flutter_bluetooth_serial package not found in cache.")
        return

    # Use the highest version found (should be only one usually)
    package_dir = os.path.join(pub_cache_path, sorted(packages)[-1])
    gradle_file = os.path.join(package_dir, 'android', 'build.gradle')

    if not os.path.exists(gradle_file):
        print(f"build.gradle not found at {gradle_file}")
        return

    print(f"Patching {gradle_file}...")

    with open(gradle_file, 'r') as f:
        content = f.read()

    # Check if namespace already exists
    if 'namespace' in content:
        print("Namespace already present. Skipping patch.")
        return

    # Add namespace inside the android { ... } block
    new_content = re.sub(
        r'android\s*{',
        'android {\n    namespace "io.github.edufolly.flutter_bluetooth_serial"',
        content
    )

    with open(gradle_file, 'w') as f:
        f.write(new_content)

    print("Successfully patched flutter_bluetooth_serial!")

if __name__ == "__main__":
    patch_bluetooth_serial()
