// Renders the Rack design boards (x-dc templates) into static HTML with their default state.
import fs from 'node:fs';
import path from 'node:path';

const [, , srcDir, outDir] = process.argv;
fs.mkdirSync(outDir, { recursive: true });

class DCLogic {
  constructor(props) { this.props = props || {}; this.state = {}; }
  setState(o) { Object.assign(this.state, typeof o === 'function' ? o(this.state) : o); }
}

function load(name) {
  const html = fs.readFileSync(path.join(srcDir, name + '.dc.html'), 'utf8');
  const helmet = (html.match(/<helmet>([\s\S]*?)<\/helmet>/) || [, ''])[1];
  const body = html.match(/<\/helmet>([\s\S]*?)<\/x-dc>/)[1];
  const sm = html.match(/<script type="text\/x-dc"[^>]*data-props='([^']*)'[^>]*>([\s\S]*?)<\/script>/);
  const meta = JSON.parse(sm[1]);
  const Cls = new Function('DCLogic', sm[2] + '\nreturn Component;')(DCLogic);
  return { helmet, body, meta, Cls };
}

const evalIn = (expr, scope) => {
  try { return new Function('scope', 'with (scope) { return (' + expr + '); }')(scope); } catch (e) { return undefined; }
};
const fill = (text, scope) => text.replace(/\{\{([\s\S]*?)\}\}/g, (_, e) => { const v = evalIn(e.trim(), scope); return v === undefined || v === null || typeof v === 'function' ? '' : String(v); });

// Finds the matching close tag for sc-for / sc-if, allowing nesting.
function block(src, start, tag) {
  const re = new RegExp('<' + tag + '\\b|</' + tag + '>', 'g');
  re.lastIndex = start; let depth = 0, m;
  while ((m = re.exec(src))) { if (m[0][1] === '/') { if (--depth === 0) return m.index; } else depth++; }
  throw new Error('unclosed ' + tag);
}

function render(src, scope, depth) {
  let out = '', i = 0;
  const open = /<(sc-for|sc-if|dc-import)\b([^>]*)>/g;
  let m;
  while ((m = open.exec(src))) {
    out += src.slice(i, m.index);
    const tag = m[1], attrs = m[2];
    const attr = (n) => { const a = attrs.match(new RegExp(n + '="([^"]*)"')); return a ? a[1] : null; };
    if (tag === 'dc-import') {
      const end = src.indexOf('</dc-import>', m.index);
      const props = {};
      attrs.replace(/([a-z-]+)="([^"]*)"/g, (_, k, v) => {
        if (k === 'name' || k === 'hint-size') return;
        const key = k.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
        const hole = v.match(/^\{\{([\s\S]*)\}\}$/);
        props[key] = hole ? evalIn(hole[1].trim(), scope) : v;
      });
      out += component(attr('name'), props, depth + 1).html;
      i = end + '</dc-import>'.length; open.lastIndex = i; continue;
    }
    const close = block(src, m.index, tag);
    const inner = src.slice(m.index + m[0].length, close);
    const hole = (attr(tag === 'sc-for' ? 'list' : 'value') || '').replace(/^\{\{|\}\}$/g, '').trim();
    const val = evalIn(hole, scope);
    if (tag === 'sc-for') {
      const as = attr('as') || 'item';
      (Array.isArray(val) ? val : []).forEach((item, idx) => { out += render(inner, Object.assign(Object.create(scope), { [as]: item, index: idx }), depth); });
    } else if (val) out += render(inner, scope, depth);
    i = close + ('</' + tag + '>').length; open.lastIndex = i;
  }
  out += src.slice(i);
  // Drop event handlers and the editor's hint attributes, then fill the remaining holes.
  out = out.replace(/\s(on[A-Z][A-Za-z]*|hint-[a-z-]+)="[^"]*"/g, '');
  return fill(out, scope);
}

function component(name, props, depth = 0) {
  const { helmet, body, meta, Cls } = load(name);
  const defaults = {};
  for (const [k, v] of Object.entries(meta)) if (!k.startsWith('$') && v && 'default' in v) defaults[k] = v.default;
  const inst = new Cls(Object.assign(defaults, props));
  const vals = inst.renderVals();
  return { html: render(body, vals, depth), helmet, meta };
}

const names = fs.readdirSync(srcDir).filter((f) => f.endsWith('.dc.html')).map((f) => f.replace('.dc.html', ''));
const sizes = {};
for (const name of names) {
  const { html, helmet, meta } = component(name, {});
  // Imported boards bring their own helmet styles; collect every board's styles so Main renders its children right.
  const styles = names.map((n) => (load(n).helmet.match(/<style>[\s\S]*?<\/style>/) || [''])[0].replace('body{margin:0}', '')).join('\n');
  const font = '<link href="https://fonts.googleapis.com/css2?family=Hanken+Grotesk:wght@400..800&family=Martian+Mono:wght@200..700&display=swap" rel="stylesheet">';
  const w = meta.$preview.width, h = meta.$preview.height;
  sizes[name] = [w, h];
  fs.writeFileSync(path.join(outDir, name + '.html'), `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Shale Rack · ${name}</title>${font}
<style>body{margin:0;background:#0e0f11}*{animation:none!important;transition:none!important}</style>${styles}</head>
<body><div style="width:${w}px;height:${h}px;padding:0;">${html}</div></body></html>\n`);
}
fs.writeFileSync(path.join(outDir, 'sizes.json'), JSON.stringify(sizes, null, 1));
console.log('rendered', names.length);
