import http from 'node:http';
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
const args=process.argv.slice(2);
const option=(name,fallback)=>{const i=args.indexOf(name);return i<0?fallback:args[i+1];};
const port=Number(option('--port',16385));
const seconds=Math.min(43200,Math.max(10,Number(option('--seconds',21600))));
const job=option('--job');
const place=option('--place','104505597931201');
const setter=Number(option('--setter',58427452));
if(!job||!Number.isInteger(port)||port<1024||port>65535)throw Error('Provide --job and a valid local port.');
const config={url:`http://127.0.0.1:${port}/snapshot`,writeToken:crypto.randomBytes(24).toString('hex'),readToken:crypto.randomBytes(24).toString('hex'),job,place,setter};
const started=Date.now();
const stats={started:new Date(started).toISOString(),posts:0,gets:0,rejected:0,maxBodyBytes:0};
let snapshot=null;
const statsPath=option('--stats','artifacts/bvl-preview-local-link-stats.json');
const configPath=option('--config','artifacts/bvl-preview-local-link-config.json');
fs.mkdirSync(path.dirname(statsPath),{recursive:true});
fs.mkdirSync(path.dirname(configPath),{recursive:true});
function valid(value,depth=0,count={n:0}){
 if(++count.n>2200||depth>9)return false;
 if(value===null||typeof value==='boolean')return true;
 if(typeof value==='number')return Number.isFinite(value)&&Math.abs(value)<1e13;
 if(typeof value==='string')return value.length<=250;
 if(typeof value!=='object')return false;
 return Object.entries(value).every(([k,v])=>!['__proto__','constructor','prototype'].includes(k)&&valid(v,depth+1,count));
}
const server=http.createServer(async(req,res)=>{
 res.setHeader('Cache-Control','no-store');
 const reject=(code)=>{stats.rejected++;res.writeHead(code).end();};
 if(req.url!=='/snapshot')return reject(404);
 if(req.headers.origin)return reject(403);
 const token=req.headers.authorization;
 if(req.method==='GET'){
  if(token!==`Bearer ${config.readToken}`)return reject(403);
  stats.gets++;
  if(!snapshot){res.writeHead(204).end();return;}
  res.setHeader('Content-Type','application/json');res.end(snapshot);return;
 }
 if(req.method!=='POST')return reject(405);
 if(token!==`Bearer ${config.writeToken}`)return reject(403);
 if(req.headers['content-type']!=='application/json')return reject(415);
 try{
  let size=0;const parts=[];
  for await(const part of req){size+=part.length;if(size>65536){reject(413);return;}parts.push(part);}
  const body=Buffer.concat(parts).toString('utf8');const data=JSON.parse(body);
  if(!valid(data)||data.schema!==1||data.job!==job||data.place!==place||data.setter!==setter||typeof data.session!=='string'||!Number.isFinite(data.sequence)||!Number.isFinite(data.stamp))return reject(422);
  if(!data.clear&&(!Array.isArray(data.path)||data.path.length<2||data.path.length>80))return reject(422);
  snapshot=body;stats.posts++;stats.maxBodyBytes=Math.max(stats.maxBodyBytes,size);res.writeHead(204).end();
 }catch{if(!res.writableEnded)reject(400);}
});
server.headersTimeout=5000;server.requestTimeout=5000;server.keepAliveTimeout=1000;
await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});
fs.writeFileSync(configPath,JSON.stringify(config));
const checkpoint=setInterval(()=>fs.writeFileSync(statsPath,JSON.stringify(stats,null,2)),5000);
let stopping=false;
const stop=()=>{if(stopping)return;stopping=true;clearInterval(checkpoint);stats.finished=new Date().toISOString();fs.writeFileSync(statsPath,JSON.stringify(stats,null,2));server.close();server.closeAllConnections();};
process.on('SIGINT',stop);process.on('SIGTERM',stop);setTimeout(stop,seconds*1000).unref();
console.log(`Preview data link listening on 127.0.0.1:${port} for ${seconds} seconds`);
