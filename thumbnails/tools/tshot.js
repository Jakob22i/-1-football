const {chromium}=require('playwright-core');const http=require('http'),fs=require('fs'),path=require('path');
const [,,out,cfg]=process.argv;
const mime={'.png':'image/png','.woff2':'font/woff2','.html':'text/html','.js':'text/javascript'};
const srv=http.createServer((rq,rs)=>{const f=path.join(__dirname,decodeURIComponent(rq.url.split('?')[0]));fs.readFile(f,(e,d)=>{if(e){rs.writeHead(404);rs.end();return}rs.writeHead(200,{'Content-Type':mime[path.extname(f)]||'application/octet-stream'});rs.end(d)})}).listen(0,async()=>{
 const b=await chromium.launch({executablePath:fs.readdirSync('/opt/pw-browsers').filter(x=>x.startsWith('chromium-')).map(x=>`/opt/pw-browsers/${x}/chrome-linux/chrome`)[0]});
 const p=await b.newPage({viewport:{width:1920,height:1080}});
 await p.goto(`http://localhost:${srv.address().port}/title.html?c=${encodeURIComponent(cfg)}`);
 await p.waitForFunction('window.__done',null,{timeout:60000});await p.waitForTimeout(300);
 await p.locator('#s').screenshot({path:out});await b.close();srv.close();});
