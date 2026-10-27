"""Read-only frozen source export for all chapter1 echo branches."""
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def do_POST(self):
        name=urlsplit(self.path).path.removeprefix('/export/')
        if name not in [f'source-{t}-{a}-{i}.json' for t in ['store','meeting','office','dorm'] for a in ['same','late','done','fix','wreck','leave','sick','pc','off'] for i in range(1,7)]:self.send_error(404);return
        size=int(self.headers['Content-Length']);assert 0<size<150_000_000
        dest=ROOT/'validation/increment03/echo'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(self.rfile.read(size))
        self.send_response(200);self.end_headers();self.wfile.write(b'OK')
    def do_GET(self):
        path=urlsplit(self.path).path
        if path in ['/src/rewind-levels.js','/src/ch1-art.js']:
            data=(ROOT/'reference/increment03/h5-source'/path.lstrip('/')).read_text()
            if path.endswith('rewind-levels.js'):data+='\nexport { buildLevel as exportBuildLevel };\n'
            else:data=data.replace('group: g, mats: all,','seed, group: g, mats: all,').replace('mesh, base, mats: [mat],','seed, mesh, base, mats: [mat],')
            raw=data.encode();self.send_response(200);self.send_header('Content-Type','text/javascript');self.end_headers();self.wfile.write(raw)
        else:super().do_GET()
    def translate_path(self,path):
        path=urlsplit(path).path
        if path=='/':return str(ROOT/'tests/increment03-echo-export.html')
        if path=='/export-scene.js':return str(ROOT/'tests/export-scene.js')
        return super().translate_path(path)
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'reference/increment03/h5-source'),**kwargs)
ThreadingHTTPServer(('127.0.0.1',8793),Handler).serve_forever()
