"""Read-only frozen source instrumentation; writes only named local export artifacts."""
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def do_POST(self):
        name=urlsplit(self.path).path.removeprefix('/export/')
        if name not in ['source-meeting.json','source-morning.json']:self.send_error(404);return
        size=int(self.headers['Content-Length']);assert 0<size<200_000_000
        dest=ROOT/'validation/chapter1'/name;dest.write_bytes(self.rfile.read(size))
        self.send_response(200);self.end_headers();self.wfile.write(b'OK')
    def do_GET(self):
        path=urlsplit(self.path).path
        if path in ['/src/ch1-scenes.js','/src/ch1-office.js','/src/ch1-art.js']:
            data=(ROOT/'reference/h5-source'/path.lstrip('/')).read_text()
            if path.endswith('ch1-scenes.js'):data+='\nexport { paintTitleSlide };\n'
            elif path.endswith('ch1-office.js'):data=data.replace('group: g, obstacles, people, props,','billboards, group: g, obstacles, people, props,')
            else:data=data.replace('group: g, mats: all,','seed, group: g, mats: all,')
            raw=data.encode();self.send_response(200);self.send_header('Content-Type','text/javascript');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
        else:super().do_GET()
    def translate_path(self,path):
        path=urlsplit(path).path
        if path=='/':return str(ROOT/'tests/chapter1-export.html')
        if path=='/export-scene.js':return str(ROOT/'tests/export-scene.js')
        return super().translate_path(path)
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'reference/h5-source'),**kwargs)
ThreadingHTTPServer(('127.0.0.1',8779),Handler).serve_forever()
