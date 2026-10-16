"""Read-only frozen module instrumentation for exact buildLevel geometry export."""
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def do_POST(self):
        name=urlsplit(self.path).path.removeprefix('/export/')
        if name not in [f'source-level-{i}.json' for i in range(1,7)]:self.send_error(404);return
        size=int(self.headers['Content-Length']);assert 0<size<150_000_000
        dest=ROOT/'validation/echo'/name;dest.write_bytes(self.rfile.read(size))
        self.send_response(200);self.end_headers();self.wfile.write(b'OK')
    def do_GET(self):
        path=urlsplit(self.path).path
        if path=='/src/rewind-levels.js':
            data=(ROOT/'reference/h5-source/src/rewind-levels.js').read_bytes()+b'\nexport { buildLevel as exportBuildLevel };\n'
            self.send_response(200);self.send_header('Content-Type','text/javascript');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
        else:super().do_GET()
    def translate_path(self,path):
        path=urlsplit(path).path
        if path=='/':return str(ROOT/'tests/echo-export.html')
        if path=='/alpha':return str(ROOT/'tests/echo-alpha-reference.html')
        if path=='/export-scene.js':return str(ROOT/'tests/export-scene.js')
        return super().translate_path(path)
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'reference/h5-source'),**kwargs)
ThreadingHTTPServer(('127.0.0.1',8778),Handler).serve_forever()
