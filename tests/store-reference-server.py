"""Build-time frozen store export, loopback only; never modifies source files."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def translate_path(self,path):
        if urlsplit(path).path=='/':return str(ROOT/'tests/store-export.html')
        return super().translate_path(path)
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'reference/h5-source'),**kwargs)
ThreadingHTTPServer(('127.0.0.1',8777),Handler).serve_forever()
