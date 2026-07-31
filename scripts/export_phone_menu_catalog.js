#!/usr/bin/env node
/** waiter_pos_catalog.dart → functions/phone_menu_catalog.json */
const fs = require('fs');
const path = require('path');

const src = fs.readFileSync(
  path.join(__dirname, '..', 'lib/features/waiter/domain/waiter_pos_catalog.dart'),
  'utf8',
);

function slug(label) {
  const map = {
    ç: 'c',
    Ç: 'c',
    ğ: 'g',
    Ğ: 'g',
    ı: 'i',
    İ: 'i',
    ö: 'o',
    Ö: 'o',
    ş: 's',
    Ş: 's',
    ü: 'u',
    Ü: 'u',
    ' ': '_',
    '.': '',
  };
  let out = '';
  for (const ch of label) out += map[ch] ?? ch.toLowerCase();
  return out.replace(/[^a-z0-9_]+/g, '');
}

// Klasör id → görünen ad (ör. w_kasarli → KAŞARLI)
const folderLabels = new Map();
const folderRe =
  /WaiterPosNode\(\s*\n?\s*id:\s*'([^']+)',\s*\n?\s*label:\s*'([^']+)',\s*\n?\s*children:/g;
let fm;
while ((fm = folderRe.exec(src))) {
  folderLabels.set(fm[1], fm[2]);
}

const leaves = [];
const directRe =
  /(?:const\s+)?WaiterPosNode\(\s*id:\s*'([^']+)',\s*label:\s*'([^']+)',\s*price:\s*([0-9.]+)\s*\)/g;
let m;
while ((m = directRe.exec(src))) {
  leaves.push({ id: m[1], name: m[2], price: Number(m[3]) });
}

const leavesRe = /_leaves\(\s*'([^']+)',\s*\{([\s\S]*?)\}\s*\)/g;
while ((m = leavesRe.exec(src))) {
  const prefix = m[1];
  const folder = folderLabels.get(prefix) || prefix;
  const body = m[2];
  const itemRe = /'([^']+)':\s*([0-9.]+)/g;
  let im;
  while ((im = itemRe.exec(body))) {
    const name = im[1];
    leaves.push({
      id: `${prefix}_${slug(name)}`,
      name: `${folder} ${name}`,
      variant: name,
      price: Number(im[2]),
      parent: prefix,
    });
  }
}

const map = new Map();
for (const L of leaves) map.set(L.id, L);
const all = [...map.values()].sort((a, b) => a.id.localeCompare(b.id));
const out = path.join(__dirname, '..', 'functions', 'phone_menu_catalog.json');
fs.writeFileSync(out, JSON.stringify(all, null, 2));
console.log('wrote', all.length, 'items →', out);
