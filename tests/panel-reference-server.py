"""Loopback-only frozen DOM reference. Does not modify the frozen source."""
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
ROOT=Path(__file__).resolve().parents[1]
class Handler(SimpleHTTPRequestHandler):
    def translate_path(self,path):
        name=urlsplit(path).path
        if name in ['/','/panel-reference.html']:return str(ROOT/'tests/panel-reference.html')
        if name=='/fixtures.json':return str(ROOT/'validation/panels/fixtures.json')
        return super().translate_path(path)
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT/'reference/h5-source'),**kwargs)
ThreadingHTTPServer(('127.0.0.1',8776),Handler).serve_forever()
