from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
ROOT=Path.cwd()
title=(ROOT/'reference/increment04/h5-source/src/title-screen.js').read_text().split('const HTML = `',1)[1].split('`;',1)[0]
html='''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/style.css"><body><script type="module">
import {DialogBox} from '/src/dialog.js';
await document.fonts.load('16px "LXGW WenKai"');
window.dialog=new DialogBox({theme:'dream'});dialog.show({text:'刚才还在……现在看清了。',face:'puzzled',stamp:'23:38'});for(let i=0;i<90;i++)dialog.update(1/60);
const skip=document.createElement('button');skip.id='skip-story';skip.innerHTML='跳过 <b>Esc</b>';document.body.append(skip);
window.makeTitle=()=>{dialog.root.hidden=true;skip.hidden=true;const r=document.createElement('div');r.id='title-screen';r.innerHTML=TITLE;r.style.setProperty('--fw',Math.min(innerWidth,innerHeight*20/9)+'px');r.style.setProperty('--fh',Math.min(innerWidth,innerHeight*20/9)*9/20+'px');r.style.setProperty('--u',Math.min(innerWidth,innerHeight*20/9)/2560+'px');r.querySelector('.ts-ui').classList.add('in');r.querySelector('.mi').classList.add('sel');document.body.append(r)};
window.ready=true;</script>'''.replace('TITLE',__import__('json').dumps(title))
class H(SimpleHTTPRequestHandler):
 def do_GET(self):
  if self.path=='/ui':
   b=html.encode();self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.end_headers();self.wfile.write(b)
  else:super().do_GET()
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT/'reference/increment04/h5-source'),**kw)
 def log_message(self,*a):pass
s=ThreadingHTTPServer(('127.0.0.1',0),H);print(s.server_port,flush=True);s.serve_forever()
