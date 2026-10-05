const {chromium}=require('playwright-core');
const http=require('http'),fs=require('fs'),path=require('path');
const [,,out,cfgFile,w='1920',h='1080']=process.argv;
const srv=http.createServer((rq,rs)=>{const f=path.join(__dirname,decodeURIComponent(rq.url.split('?')[0]));fs.readFile(f,(e,d)=>{if(e){rs.writeHead(404);rs.end();return}
rs.writeHead(200,{'Content-Type':f.endsWith('.js')?'text/javascript':f.endsWith('.json')?'application/json':'text/html'});rs.end(d)})}).listen(0,async()=>{
 const b=await chromium.launch({executablePath:fs.readdirSync('/opt/pw-browsers').filter(x=>x.startsWith('chromium-')).map(x=>`/opt/pw-browsers/${x}/chrome-linux/chrome`)[0],args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--enable-webgl']});
 const p=await b.newPage({viewport:{width:+w,height:+h}});
 p.on('console',m=>{const t=m.text();if(!t.includes('404'))console.log('console:',t)});p.on('pageerror',e=>console.log('err:',e.message));
 const cfg=fs.readFileSync(cfgFile,'utf8');
 await p.goto(`http://localhost:${srv.address().port}/${process.env.SCENE||'scene2.html'}?w=${w}&h=${h}&cfg=${encodeURIComponent(cfg)}`);
 await p.waitForFunction('window.__done',null,{timeout:560000});
 const d=await p.evaluate(()=>document.getElementById('c').toDataURL('image/png'));
 fs.writeFileSync(out,Buffer.from(d.split(',')[1],'base64'));
 await b.close();srv.close();
});
