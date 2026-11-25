"""Dart VM HTTP driver for the isolated journal audit window (stdlib only).

Run with the native runtime log as the first argument, followed by JSON args.
Example: python3 native_driver.py /tmp/qp-journal-audit/native-runtime.txt '{"action":"seed","count":"35"}'
The log supplies the ephemeral VM URL; no credentials are stored here.
"""
import json
from pathlib import Path
import re
import sys
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent


def window():
    return next(w for w in json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))
                if w['class'] == 'com.blackpiratex.quietpaper')


def dispatch(expression):
    output = subprocess.check_output(['hyprctl', 'eval', 'hl.dispatch(' + expression + ')'], text=True)
    if 'error:' in output:
        raise RuntimeError(output)


def key(name, mods=''):
    target = json.dumps('address:' + window()['address'])
    dispatch('hl.dsp.focus({window=' + target + '})')
    dispatch('hl.dsp.send_shortcut({window=' + target + ',mods=' + json.dumps(mods) + ',key=' + json.dumps(name) + '})')
    time.sleep(.065)


def type_text(value):
    plain = {' ': 'space', '\n': 'Return', '.': 'period', '-': 'minus', '/': 'slash'}
    for char in value:
        key(plain.get(char, char.lower()), 'SHIFT' if char.isupper() else '')


def resize(width, height):
    target = json.dumps('address:' + window()['address'])
    dispatch('hl.dsp.window.float({window=' + target + ',action="enable"})')
    dispatch('hl.dsp.window.resize({window=' + target + ',x=' + str(width) + ',y=' + str(height) + ',relative=false})')
    time.sleep(.6)


def call(log, **args):
    source = Path(log).read_text()
    url = re.findall(r'A Dart VM Service on Linux is available at: (http://\S+)', source)[-1]
    vm = json.load(urllib.request.urlopen(url + 'getVM', timeout=15))['result']
    isolate = next(i['id'] for i in vm['isolates'] if i['name'] == 'main')
    query = urllib.parse.urlencode({'isolateId': isolate, **args})
    reply = json.load(urllib.request.urlopen(url + 'ext.journalAudit?' + query, timeout=120))
    result = reply.get('result', reply)
    if len(result.get('notes', [])) > 50:
        result['notes'] = result['notes'][:5] + result['notes'][-5:]
        result['notesTruncated'] = True
    with (ROOT / 'native-results.jsonl').open('a') as stream:
        stream.write(json.dumps({'request': args, 'result': result}, ensure_ascii=False) + '\n')
    return result


if __name__ == '__main__':
    result = call(sys.argv[1], **(json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}))
    print(json.dumps({k: v for k, v in result.items() if k not in ('notes',)}, ensure_ascii=False, indent=2))
