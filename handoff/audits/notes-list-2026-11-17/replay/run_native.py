"""Run the already-built profile harness in an isolated native window.
Build the Dart entry point first; see the audit README for the command.
Only the window whose /proc executable matches this checkout's profile bundle
is resized. Does not interact with the installed app or its data.
"""
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import time

repo = Path(__file__).resolve().parents[4]
binary = repo / 'build/linux/x64/profile/bundle/quitepaper'
root = Path(tempfile.mkdtemp(prefix='qp-notes-native-'))
env = os.environ.copy()
for key, folder in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
    (root / folder).mkdir()
    env[key] = str(root / folder)
(root / 'output').mkdir()
env['QP_NOTES_AUDIT_OUT'] = str(root / 'output')
with (root / 'native.log').open('w') as log:
    process = subprocess.Popen(['dbus-run-session', '--', str(binary)], env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(300):
            clients = json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))
            matches = [c for c in clients if Path(f"/proc/{c['pid']}/exe").resolve() == binary]
            if matches:
                window = matches[0]
                address = window['address']
                if not window['floating']:
                    subprocess.run(['hyprctl', 'dispatch', f"hl.dsp.window.float({{action='toggle', window='address:{address}'}})"], check=True)
                subprocess.run(['hyprctl', 'dispatch', f"hl.dsp.window.resize({{x=1300,y=720,relative=false,window='address:{address}'}})"], check=True)
                break
            if process.poll() is not None:
                raise RuntimeError('Harness exited before a window appeared')
            time.sleep(.1)
        else:
            raise TimeoutError('Harness window did not appear')
        code = process.wait(timeout=180)
        if code:
            raise RuntimeError(f'Harness exited {code}')
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
for filename, expected in [('desktop.png', (1280, 680)), ('phone.png', (390, 680))]:
    data = (root / 'output' / filename).read_bytes()
    actual = struct.unpack('>II', data[16:24])
    if actual != expected:
        raise AssertionError(f'{filename}: actual render size {actual}, expected {expected}')
metrics = json.loads((root / 'output/native-profile.json').read_text())
assert not metrics['errors'], metrics['errors']
(root / 'window-verification.json').write_text(json.dumps({'desktopScreenshotPixels': [1280, 680], 'phoneScreenshotPixels': [390, 680], 'windowConfiguredDp': [1300, 720]}, indent=2))
print(root, flush=True)
