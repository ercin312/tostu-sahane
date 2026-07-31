#!/usr/bin/env node
/**
 * Telefon agent'ını base prompt + Firestore eğitimleriyle günceller.
 *
 *   node scripts/configure_elevenlabs_phone_agent.js
 */

const path = require('path');
const { spawnSync } = require('child_process');

// Menü JSON güncel olsun
spawnSync(
  process.execPath,
  [path.join(__dirname, 'export_phone_menu_catalog.js')],
  { stdio: 'inherit' },
);

// functions/.env yükle
require(path.join(__dirname, '..', 'functions', 'elevenlabs_config')).loadDotEnvOnce();

async function main() {
  // Firebase admin opsiyonel — yerelde sadece prompt sync
  try {
    // eslint-disable-next-line global-require
    const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));
    if (!admin.apps.length) {
      admin.initializeApp({ projectId: 'tostusahane-e4e71' });
    }
  } catch (_) {
    try {
      // eslint-disable-next-line global-require
      const admin = require('firebase-admin');
      if (!admin.apps.length) {
        admin.initializeApp({ projectId: 'tostusahane-e4e71' });
      }
    } catch (e) {
      console.warn('firebase-admin yok; eğitim okunamadı, sadece base prompt sync.');
    }
  }

  // eslint-disable-next-line global-require
  const {
    readTraining,
    syncAgent,
  } = require(path.join(__dirname, '..', 'functions', 'phone_ai_training'));

  let training = { examples: [], styleNotes: '' };
  try {
    // eslint-disable-next-line global-require
    const admin = require('firebase-admin');
    training = await readTraining(admin.firestore());
  } catch (e) {
    console.warn('Firestore eğitim okunamadı:', e.message);
  }

  const result = await syncAgent(training);
  console.log('OK', result);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
