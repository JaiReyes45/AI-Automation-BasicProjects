"""Apply pending versioned migrations without resetting edited catalog records."""
import pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
DB=sys.argv[1] if len(sys.argv)>1 else 'presales'
if not DB.replace('_','').isalnum():raise SystemExit('Invalid database name')
def sql(text):
    p=subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d',DB,'-At','-v','ON_ERROR_STOP=1'],input=text,text=True,capture_output=True)
    if p.returncode:raise RuntimeError(p.stderr)
    return p.stdout.strip()
has=sql("SELECT to_regclass('presales.schema_migrations') IS NOT NULL;")=='t'
applied=set(sql('SELECT version FROM presales.schema_migrations;').splitlines()) if has else set()
for path in sorted((ROOT/'database').glob('[0-9][0-9][0-9]_*.sql')):
    version=path.name[:3]
    if version in applied:
        print('Already applied:',version);continue
    sql(path.read_text());print('Applied:',path.name)
