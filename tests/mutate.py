"""Mutation check on a temp copy. Usage: python mutate.py [id ...]. Prints id, expected, actual failing test names."""
import os, re, shutil, subprocess, sys, tempfile

SRC = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASH = r'C:\Program Files\Git\bin\bash.exe'

# id: (file, old, new, which test, prediction)
M = {
 'M1': ('lazy-pack/code-and-ai-audit.mjs', "String(u).replace(/\\/\\/[^/\\s]*@/g", "String(u).replace(/\\/\\/[^/@\\s]*@/g", 'audit', '無測試抓得到（密碼含 @ 沒有測資）'),
 'M2': ('lazy-pack/code-and-ai-audit.mjs', "process.platform === 'win32' && cmdArgs.some(", "false && cmdArgs.some(", 'audit', '無（Windows 才生效，測試沒有含特殊字元的 runCmd 參數）'),
 'M3': ('lazy-pack/code-and-ai-audit.mjs', "'--depth', '1', '--', url, dest]", "'--depth', '1', url, dest]", 'audit', '無'),
 'M4': ('lazy-pack/code-and-ai-audit.mjs', "const bad = args.find((a) => a.startsWith('--') && !FLAGS.has(a));", "const bad = null;", 'audit', 't8k[--bogus] 與 t8k'),
 'M5': ('lazy-pack/code-and-ai-audit.mjs', "if (!isSelfTest) fs.writeFileSync(STATE_FILE", "if (true) fs.writeFileSync(STATE_FILE", 'audit', '可能無（self-test 後狀態檔存在與否沒有斷言）'),
 'M6': ('lazy-pack/code-and-ai-audit.mjs', "if (/^(https|file):\\/\\/[^/]*@/.test(url)) {", "if (false) {", 'audit', 't8l'),
 'M7': ('lazy-pack/gcp-setup-and-check.sh', 'if ! gcloud sql instances patch "$SQL_INSTANCE" "$@" --project="$PROJECT_ID"; then', 'if ! { gcloud sql instances patch "$SQL_INSTANCE" "$@" --project="$PROJECT_ID" || true; }; then', 'gcp', 't9a'),
 'M8': ('lazy-pack/gcp-setup-and-check.sh', 'elif printf "%s" "$secret_val" | gcloud secrets create "$SECRET_NAME" --data-file=- --project="$PROJECT_ID"; then', 'elif printf "%s" "$secret_val" | gcloud secrets create "$SECRET_NAME" --data-file=- --project="$PROJECT_ID" || true; then', 'gcp', 't10'),
 'M9': ('lazy-pack/gcp-setup-and-check.sh', 'if [ "$MODE" = "dry-run" ]; then\n  echo "ℹ️  [模擬模式] 不寫入狀態檔', 'if false; then\n  echo "ℹ️  [模擬模式] 不寫入狀態檔', 'gcp', 't6'),
 'M10': ('lazy-pack/gcp-setup-and-check.sh', '[ -t 0 ] || PROJECT_AUTO_PICK="true"', ':', 'gcp', 't5b'),
 'M11': ('lazy-pack/gcp-setup-and-check.sh', 'if [ "$#" -eq 0 ] && [ "$MODE" != "dry-run" ]; then\n              echo "⏭️  [已符合', 'if false; then\n              echo "⏭️  [已符合', 'gcp', '無（沒有測資走到已是 g1-small 的 3A）'),
 'M12': ('lazy-pack/gcp-setup-and-check.sh', 'if [ "$PRIVATE_NETWORK" = "Unknown" ]; then', 'if false; then', 'gcp', '無（沒有 describe 失敗的私有網路測資）'),
}


def run(mid):
    f, old, new, which, pred = M[mid]
    d = tempfile.mkdtemp(prefix='mut-')
    dst = os.path.join(d, 'r')
    shutil.copytree(SRC, dst, ignore=shutil.ignore_patterns('.git', 'reports', 'node_modules'))
    p = os.path.join(dst, *f.split('/'))
    s = open(p, 'rb').read().decode('utf-8')
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    assert s.count(old) == 1, (mid, s.count(old))
    s = s.replace(old, new)
    if crlf:
        s = s.replace('\n', '\r\n')
    open(p, 'wb').write(s.encode('utf-8'))
    os.makedirs(os.path.join(dst, 'reports'), exist_ok=True)
    t = 'tests/test-code-audit.sh' if which == 'audit' else 'tests/test-gcp-setup.sh'
    env = dict(os.environ)
    r = subprocess.run([BASH, t], cwd=dst, capture_output=True, text=True, encoding='utf-8', errors='replace', env=env, timeout=500)
    out = r.stdout + r.stderr
    fails = re.findall(r'FAIL \[([^\]]*(?:\[[^\]]*\])?[^\]]*)\]', out)
    last = [l for l in out.splitlines() if l.startswith('PASS=')]
    print(mid, '| 預期:', pred, '| 實際 rc=%s' % r.returncode, '| 失敗項:', sorted(set(fails)) or '無', '|', last[-1] if last else out[-200:], flush=True)
    shutil.rmtree(d, ignore_errors=True)


if __name__ == '__main__':
    ids = sys.argv[1:] or list(M)
    for i in ids:
        run(i)
