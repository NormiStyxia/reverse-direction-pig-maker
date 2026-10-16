"""Read-only access to frozen buildDust; append only a test export in memory."""
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
root=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
 def do_GET(self):
  if urlsplit(self.path).path=='/reference/h5-source/src/world.js':
   data=(root/'reference/h5-source/src/world.js').read_bytes()+b'\nexport {buildDust as exportBuildDust};\n'
   self.send_response(200);self.send_header('Content-Type','text/javascript');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
  else:super().do_GET()
 def __init__(self,*args,**kw):super().__init__(*args,directory=str(root),**kw)
ThreadingHTTPServer(('127.0.0.1',8781),Handler).serve_forever()
