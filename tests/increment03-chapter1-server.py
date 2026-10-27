"""Read-only frozen source instrumentation; writes only named local export artifacts."""
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def do_POST(self):
        name=urlsplit(self.path).path.removeprefix('/export/')
        if name not in ['source-meeting.json','source-morning.json','source-dorm.json','source-night.json','source-dream.json','source-timeline.json','source-walkers.json']:self.send_error(404);return
        size=int(self.headers['Content-Length']);assert 0<size<200_000_000
        dest=ROOT/'validation/increment03/chapter1'/name;dest.write_bytes(self.rfile.read(size))
        self.send_response(200);self.end_headers();self.wfile.write(b'OK')
    def do_GET(self):
        path=urlsplit(self.path).path
        if path in ['/src/ch1-scenes.js','/src/ch1-office.js','/src/ch1-art.js']:
            data=(ROOT/'reference/increment03/h5-source'/path.lstrip('/')).read_text()
            if path.endswith('ch1-scenes.js'):pass
            elif path.endswith('ch1-office.js'):data=data.replace('group: g, obstacles, people, props,','billboards, group: g, obstacles, people, props,')
            else:data=data.replace('group: g, mats: all,','seed, group: g, mats: all,')
            raw=data.encode();self.send_response(200);self.send_header('Content-Type','text/javascript');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
        else:super().do_GET()
    def translate_path(self,path):
        path=urlsplit(path).path
        if path=='/':return str(ROOT/'tests/increment03-chapter1-export.html')
        if path=='/dorm':return str(ROOT/'tests/increment03-dorm-export.html')
        if path=='/night':return str(ROOT/'tests/increment03-night-export.html')
        if path=='/timeline':return str(ROOT/'tests/increment03-timeline-export.html')
        if path=='/walkers':return str(ROOT/'tests/increment03-walkers-export.html')
        if path=='/dream':return str(ROOT/'tests/increment03-dream-export.html')
        if path=='/export-scene.js':return str(ROOT/'tests/export-scene.js')
        return super().translate_path(path)
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'reference/increment03/h5-source'),**kwargs)
if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8794)
    ThreadingHTTPServer(('127.0.0.1',parser.parse_args().port),Handler).serve_forever()
