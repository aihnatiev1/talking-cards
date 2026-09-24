import { bundle } from '@remotion/bundler';
import { renderStill, selectComposition } from '@remotion/renderer';
import { access, mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'out/store-refresh');
const captures = [];
for (const locale of ['uk', 'en']) {
  for (const screen of ['cards', 'sounds', 'game', 'draw', 'fill', 'home', 'quest']) {
    const file = `public/screenshots/auto/refresh-${screen}-${locale}.png`;
    await access(path.join(root, file)); // Never silently use an older fallback.
    const info = await stat(path.join(root, file));
    captures.push({ file, capturedAt: info.mtime.toISOString() });
  }
}
await mkdir(output, { recursive: true });
const serveUrl = await bundle({ entryPoint: path.join(root, 'src/index.ts'), publicDir: path.join(root, 'public') });
const outputs = [];
async function renderShot(locale, slot, variant = 'control') {
  const inputProps = { locale, slot, variant };
  // selectComposition resolves props; renderStill must receive a composition
  // selected with these exact props, not the cached first slide's props.
  const composition = await selectComposition({ serveUrl, id: 'StoreScreenshot', inputProps });
  const filename = `slot-${slot}-${locale}${variant === 'control' ? '' : '-play'}.png`;
  const destination = path.join(output, filename);
  await renderStill({ serveUrl, composition, imageFormat: 'png', output: destination, inputProps });
  const sha256 = createHash('sha256').update(await readFile(destination)).digest('hex');
  if (outputs.some(item => item.sha256 === sha256)) {
    throw new Error(`Duplicate rendered slide: ${filename}`);
  }
  outputs.push({ filename, locale, slot, variant, sha256 });
}
for (const locale of ['uk', 'en']) {
  for (let slot = 1; slot <= 7; slot++) {
    await renderShot(locale, slot);
    console.log(`Rendered ${locale} ${slot}/7`);
  }
}
for (const locale of ['uk', 'en']) await renderShot(locale, 1, 'play');
const overview = await selectComposition({ serveUrl, id: 'StoreOverview' });
await renderStill({ serveUrl, composition: overview, imageFormat: 'png', output: path.join(output, 'overview.png') });
await writeFile(path.join(output, 'manifest.json'), JSON.stringify({ renderedAt: new Date().toISOString(), dimensions: [1290, 2796], captures, outputs }, null, 2));
const groups = ['uk', 'en'].map(locale => `<section><h2>${locale === 'uk' ? 'Українська' : 'English'}</h2><div class="grid">${Array.from({length: 7}, (_, i) => `<a href="slot-${i + 1}-${locale}.png"><img src="slot-${i + 1}-${locale}.png" alt="${locale} — слайд ${i + 1}"><span>${i + 1}</span></a>`).join('')}</div></section>`).join('');
await writeFile(path.join(output, 'index.html'), `<!doctype html><html lang="uk"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>FirstWords — ASO</title><style>body{margin:0;padding:32px;background:#fffbf0;color:#3f3635;font:16px system-ui}h1{font-size:32px}p{max-width:720px;line-height:1.5;color:#6b605b}.grid{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:16px}a{color:inherit;text-align:center;text-decoration:none}img{width:100%;border-radius:18px;box-shadow:0 8px 24px #3f36351a}span{display:block;padding:8px}section{margin-top:36px}@media(max-width:1000px){.grid{grid-template-columns:repeat(3,1fr)}}@media(max-width:550px){body{padding:16px}.grid{grid-template-columns:repeat(2,1fr)}}</style><h1>Перші слова — разом</h1><p>14 слайдів на основі актуального застосунку. Натисніть на зображення, щоб відкрити повний розмір. Комплект для перевірки; ще не опубліковано.</p>${groups}<section><h2>Варіант першого слайда для A/B-тесту</h2><p>Змінюється лише заголовок. Тест ще не запущений.</p><div class="grid"><a href="slot-1-uk-play.png"><img src="slot-1-uk-play.png" alt="Український варіант про гру"></a><a href="slot-1-en-play.png"><img src="slot-1-en-play.png" alt="English play headline variant"></a></div></section></html>`);
console.log(`Review: ${path.join(output, 'index.html')}`);
