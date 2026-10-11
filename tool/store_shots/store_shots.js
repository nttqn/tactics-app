// Usage: node store_shots.js <outDir> <width> <height> <scale>
const http = require('http'), fs = require('fs'), path = require('path');
const { chromium } = require('playwright');

const [outDir, W, H, SCALE] = [
  process.argv[2],
  Number(process.argv[3]),
  Number(process.argv[4]),
  Number(process.argv[5]),
];
fs.mkdirSync(outDir, { recursive: true });

const root = 'C:/Users/Hi/.gemini/antigravity/scratch/tactics-app/build/web';
const types = {
  '.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.otf': 'font/otf', '.ttf': 'font/ttf',
  '.png': 'image/png', '.mp3': 'audio/mpeg', '.wav': 'audio/wav',
};
const server = http.createServer((req, res) => {
  let p = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (fs.existsSync(p) && fs.statSync(p).isDirectory()) p = path.join(p, 'index.html');
  if (!fs.existsSync(p)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
}).listen(8131);

// Where the board sits: between the 58px status bar and the 112px panel.
const TOP = 58, PANEL = 112;
function tileCentre(info, x, y) {
  const areaH = H - TOP - PANEL;
  const zoom = Math.min(W / (info.w * 64 + 16), areaH / (info.h * 64 + 16));
  const t = 64 * zoom;
  const left = (W - info.w * t) / 2, top = TOP + (areaH - info.h * t) / 2;
  return [left + (x + 0.5) * t, top + (y + 0.5) * t];
}

(async () => {
  const browser = await chromium.launch();
  let n = 0;
  async function open(shot) {
    const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: SCALE });
    let info = null;
    page.on('console', (m) => {
      const text = m.text();
      if (text.startsWith('SHOT:')) info = JSON.parse(text.slice(5));
    });
    await page.goto(`http://localhost:8131/?shot=${shot}&nocache=${Date.now()}`);
    await page.waitForTimeout(6000);
    return { page, info: () => info };
  }
  const save = async (page, name) => {
    n++;
    await page.screenshot({ path: path.join(outDir, `${n}-${name}.png`) });
  };

  let s = await open('home');
  await save(s.page, 'home');
  await s.page.close();

  s = await open('battle');
  let info = s.info();
  if (!info || !info.unit) throw new Error('battle position missing: ' + JSON.stringify(info));
  await s.page.mouse.click(...tileCentre(info, ...info.unit));
  await s.page.waitForTimeout(500);
  await save(s.page, 'battle-move');
  await s.page.mouse.click(...tileCentre(info, ...info.to));
  await s.page.waitForTimeout(900);
  await s.page.mouse.click(8 + (W - 16) / 8, H - PANEL / 2); // Attack
  await s.page.waitForTimeout(400);
  if (!info.single) {
    await s.page.mouse.click(...tileCentre(info, ...info.target));
    await s.page.waitForTimeout(400);
  }
  await save(s.page, 'battle-attack');
  await s.page.close();

  s = await open('fog');
  await save(s.page, 'fog-of-war');
  await s.page.close();

  s = await open('campaign');
  await save(s.page, 'campaign');
  await s.page.close();

  s = await open('home');
  await s.page.mouse.click(W / 2, 358); // Skirmish
  await s.page.waitForTimeout(1200);
  await save(s.page, 'commanders');
  await s.page.close();

  s = await open('editor');
  await save(s.page, 'map-editor');
  await s.page.close();

  s = await open('achievements');
  await save(s.page, 'achievements');
  await s.page.close();

  await browser.close();
  server.close();
  console.log(`${n} screenshots in ${outDir}`);
})().catch((e) => { console.error(e); process.exit(1); });
