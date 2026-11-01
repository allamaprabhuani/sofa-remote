# Disposable keychain/certificate fixtures. Never launches apps or changes trust/TCC.
from pathlib import Path
import subprocess,shlex,secrets,shutil,plistlib,hashlib,os,tempfile
root=Path(__file__).resolve().parents[2]
work=Path(tempfile.mkdtemp(prefix='sofa-signing-',dir=os.environ.get('SOFA_TEST_TMP')))
openssl=shutil.which('openssl')
if not openssl: raise RuntimeError('OpenSSL is required for disposable signing fixtures')
openssl_version=subprocess.check_output([openssl,'version'],text=True)
modern_openssl=openssl_version.startswith('OpenSSL ') and int(openssl_version.split()[1].split('.')[0]) >= 3
k=work/'test.keychain-db';pw=secrets.token_urlsafe(32)
reports=[]
def run(args, data=None, success=True):
 p=subprocess.run(args,input=data,capture_output=True,text=True)
 if success and p.returncode: raise RuntimeError('Fixture operation failed: '+p.stderr[-1500:])
 return p
try:
 run(['security','create-keychain','-p',pw,str(k)])
 run(['security','unlock-keychain','-p',pw,str(k)])
 # Keep fixture credentials out of the user's default search list.
 current=shlex.split(subprocess.check_output(['security','list-keychains','-d','user'],text=True))
 run(['security','list-keychains','-d','user','-s',*[item for item in current if Path(item)!=k]])
 def identity(name):
  key=work/(name+'.key');cert=work/(name+'.pem')
  run([openssl,'genrsa',*(['-traditional'] if modern_openssl else []),'-out',str(key),'2048']);key.chmod(0o600)
  config=work/(name+'.cnf')
  config.write_text('[req]\nprompt = no\ndistinguished_name = dn\nx509_extensions = signing\n[dn]\nCN = '+name+'\n[signing]\nbasicConstraints = critical,CA:false\nkeyUsage = critical,digitalSignature\nextendedKeyUsage = critical,codeSigning\n')
  run([openssl,'req','-new','-x509','-key',str(key),'-out',str(cert),'-days','2','-config',str(config)])
  run(['security','import',str(key),'-k',str(k),'-t','priv','-f','openssl','-x','-T','/usr/bin/codesign'])
  run(['security','import',str(cert),'-k',str(k),'-t','cert','-f','pemseq'])
  der=subprocess.check_output([openssl,'x509','-in',str(cert),'-outform','DER'])
  return hashlib.sha1(der).hexdigest().upper()
 first=identity('Developer ID Application: Test Fixture A (AAAAAAAAAA)');second=identity('Sofa Signing Fixture B')
 def make(name,version):
  app=work/(name+'.app');(app/'Contents/MacOS').mkdir(parents=True)
  (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'org.sofaremote.fixture','CFBundleExecutable':'Fixture','CFBundleName':'Signing Fixture','CFBundlePackageType':'APPL','CFBundleVersion':str(version)}))
  source=work/(name+'.c');source.write_text(f'int main(void){{return {version};}}\n')
  run(['xcrun','clang','-arch','arm64','-arch','x86_64','-mmacosx-version-min=14.0',str(source),'-o',str(app/'Contents/MacOS/Fixture')])
  return app
 a=make('Old',1);b=make('New',2)
 def sign(app,identity,extra=[]):run(['codesign','--force','--sign',identity,'--keychain',str(k),'--timestamp=none',*extra,str(app)])
 sign(a,first);sign(b,first)
 os.environ.setdefault('SOFA_BUILD_DIR',str(root/'.build'))
 def verify(app,previous=None,mode='certificate',ok=True):
  args=[str(root/'scripts/verify-signing.sh'),'--mode',mode,'--bundle-id','org.sofaremote.fixture','--app',str(app)]
  if previous:args+=['--previous',str(previous)]
  if mode=='release':args+=['--team','AAAAAAAAAA']
  p=run(args,success=False)
  assert (p.returncode==0)==ok,p.stderr
  return p
 verify(b,a);reports.append('PASS distinct universal versions retain the same default certificate-backed identity')
 for name,identity,extra in [('Foreign',second,[]),('Adhoc','-',[]),('Weak',first,['--requirements','=designated => identifier "org.sofaremote.fixture"'])]:
  c=work/(name+'.app');shutil.copytree(b,c);sign(c,identity,extra);verify(c,a,ok=False);reports.append('PASS rejects '+name)
 c=work/'Tampered.app';shutil.copytree(b,c);(c/'Contents/Info.plist').write_bytes((c/'Contents/Info.plist').read_bytes()+b'\n');verify(c,a,ok=False);reports.append('PASS rejects signature tampering')
 verify(b,mode='release',ok=False);reports.append('PASS self-signed fixture cannot pass Developer ID release policy')
 print('\n'.join(reports))
finally:
 subprocess.run(['security','delete-keychain',str(k)],capture_output=True)
 shutil.rmtree(work)
