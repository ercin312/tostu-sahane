#!/usr/bin/env node
/**
 * Excel / CSV → phone_customers
 *
 * Kullanım:
 *   node scripts/import_phone_customers.js "C:\path\musteriler.xlsx"
 *   node scripts/import_phone_customers.js "C:\path\musteriler.csv"
 *
 * Sütun başlıkları (büyük/küçük harf fark etmez):
 *   telefon | phone | numara
 *   isim | ad | name
 *   firma | company | sirket
 *   adres | address
 *   tarif | directions | yol_tarifi | not | note
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

function parseCsv(text) {
  const lines = text
    .replace(/^\uFEFF/, '')
    .split(/\r?\n/)
    .filter((l) => l.trim());
  if (lines.length < 2) return [];
  const sep = lines[0].includes(';') ? ';' : ',';
  const headers = lines[0].split(sep).map((h) => h.trim().replace(/^"|"$/g, ''));
  return lines.slice(1).map((line) => {
    const cols = line.split(sep).map((c) => c.trim().replace(/^"|"$/g, ''));
    const row = {};
    headers.forEach((h, i) => {
      row[h] = cols[i] || '';
    });
    return row;
  });
}

async function parseXlsx(filePath) {
  let XLSX;
  try {
    // eslint-disable-next-line global-require
    XLSX = require('xlsx');
  } catch (_) {
    console.error(
      'xlsx paketi yok. Kurulu değilse: cd functions && npm i xlsx',
    );
    console.error('veya Excel\'den CSV kaydedip tekrar deneyin.');
    process.exit(1);
  }
  const wb = XLSX.readFile(filePath);
  const sheet = wb.Sheets[wb.SheetNames[0]];
  return XLSX.utils.sheet_to_json(sheet, { defval: '' });
}

function postJson(url, body, secret) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const data = JSON.stringify(body);
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
          ...(secret ? { 'X-Phone-Order-Secret': secret } : {}),
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => {
          raw += c;
        });
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, json: JSON.parse(raw || '{}') });
          } catch (_) {
            resolve({ status: res.statusCode, json: { raw } });
          }
        });
      },
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Kullanım: node scripts/import_phone_customers.js <dosya.xlsx|csv>');
    process.exit(1);
  }
  const abs = path.resolve(file);
  if (!fs.existsSync(abs)) {
    console.error('Dosya yok:', abs);
    process.exit(1);
  }

  const ext = path.extname(abs).toLowerCase();
  let rows;
  if (ext === '.csv' || ext === '.txt') {
    rows = parseCsv(fs.readFileSync(abs, 'utf8'));
  } else if (ext === '.xlsx' || ext === '.xls') {
    rows = await parseXlsx(abs);
  } else {
    console.error('Desteklenen: .xlsx .xls .csv');
    process.exit(1);
  }

  const url =
    process.env.IMPORT_URL ||
    'https://us-central1-tostusahane-e4e71.cloudfunctions.net/importPhoneCustomers';
  const secret = process.env.PHONE_ORDER_SECRET || '';

  console.log(`${rows.length} satır okundu → ${url}`);
  const result = await postJson(url, { rows }, secret);
  console.log(result.status, result.json);
  if (result.status >= 400) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
