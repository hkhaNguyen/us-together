// Builds the demo app, paints its stand-in photos and photographs each screen
// with headless Chrome into .github/screenshots/. From the repo root:
//   node tool/screenshots/shoot.mjs
import { execFileSync, spawn } from 'node:child_process';
import { createReadStream, existsSync, mkdirSync, mkdtempSync, statSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { extname, join, resolve } from 'node:path';

// Relative: on Windows the flutter calls go through a shell, where a space
// in an absolute path would split the argument.
const build = 'build/demo_web';
const root = resolve(build);
const out = resolve('.github/screenshots');
const phone = { width: 390, height: 844, mobile: true };
const desktop = { width: 1440, height: 900, mobile: false };
const shots = [
  ...['login', 'home', 'moment', 'photo', 'anniversaries', 'trash', 'add-photos', 'add-moment', 'edit-moment'].map((screen) => ({ screen, name: screen, ...phone })),
  { screen: 'home', name: 'home-desktop', ...desktop },
  { screen: 'moment', name: 'moment-desktop', ...desktop },
];
const chrome = process.env.CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const shell = process.platform === 'win32';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

if (!process.argv.includes('--no-build')) {
  execFileSync('flutter', ['build', 'web', '--release', '--no-web-resources-cdn', '-t', 'tool/screenshots/demo_main.dart', '-o', build], { stdio: 'inherit', shell });
  execFileSync('flutter', ['test', 'tool/screenshots/demo_photos_test.dart'], {
    stdio: 'inherit',
    shell,
    env: { ...process.env, DEMO_PHOTOS_DIR: `${build}/demo-photos` },
  });
}

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png' };
const server = createServer((req, res) => {
  let file = join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
  res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
  createReadStream(file).pipe(res);
}).listen(0);
const port = server.address().port;

// Driven over the DevTools protocol, so each shot waits real time for
// CanvasKit, the web fonts, the photos and the opening animations.
const debugPort = 9300 + Math.floor(Math.random() * 600);
const browser = spawn(chrome, [
  '--headless=new',
  '--hide-scrollbars',
  '--enable-unsafe-swiftshader',
  `--remote-debugging-port=${debugPort}`,
  `--user-data-dir=${mkdtempSync(join(tmpdir(), 'us-together-shots-'))}`,
  'about:blank',
]);

try {
  let target;
  for (let i = 0; i < 50 && !target; i++) {
    await sleep(200);
    target = await fetch(`http://127.0.0.1:${debugPort}/json/list`)
      .then((r) => r.json())
      .then((list) => list.find((t) => t.type === 'page'))
      .catch(() => undefined);
  }
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r, { once: true }));
  let id = 0;
  const pending = new Map();
  ws.addEventListener('message', ({ data }) => {
    const msg = JSON.parse(data);
    pending.get(msg.id)?.(msg.result);
  });
  const send = (method, params = {}) =>
    new Promise((r) => {
      pending.set(++id, r);
      ws.send(JSON.stringify({ id, method, params }));
    });

  mkdirSync(out, { recursive: true });
  for (const { screen, name, width, height, mobile } of shots) {
    await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: mobile ? 2 : 1, mobile });
    await send('Page.navigate', { url: `http://localhost:${port}/?screen=${screen}` });
    await sleep(9000);
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(join(out, `${name}.png`), Buffer.from(data, 'base64'));
    console.log(`shot ${name}`);
  }
  ws.close();
} finally {
  browser.kill();
  server.close();
}
