/**
 * ElevenLabs ayarları — process.env / functions.config / yerel .env
 * API key asla log'a yazılmaz.
 */

const fs = require('fs');
const path = require('path');

let _fileEnvLoaded = false;

function loadDotEnvOnce() {
  if (_fileEnvLoaded) return;
  _fileEnvLoaded = true;
  try {
    const envPath = path.join(__dirname, '.env');
    if (!fs.existsSync(envPath)) return;
    const text = fs.readFileSync(envPath, 'utf8');
    for (const line of text.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      const key = trimmed.slice(0, eq).trim();
      let value = trimmed.slice(eq + 1).trim();
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }
      if (process.env[key] == null || process.env[key] === '') {
        process.env[key] = value;
      }
    }
  } catch (_) {
    // ignore
  }
}

function functionsConfigSafe() {
  try {
    // eslint-disable-next-line global-require
    const functions = require('firebase-functions');
    return functions.config() || {};
  } catch (_) {
    return {};
  }
}

function getElevenLabsConfig() {
  loadDotEnvOnce();
  const cfg = functionsConfigSafe().elevenlabs || {};
  return {
    apiKey: process.env.ELEVENLABS_API_KEY || cfg.api_key || '',
    voiceId:
      process.env.ELEVENLABS_VOICE_ID ||
      cfg.voice_id ||
      'N0wraTTB0pquzsz3DLG8',
    modelId:
      process.env.ELEVENLABS_MODEL_ID ||
      cfg.model_id ||
      'eleven_multilingual_v2',
  };
}

function assertElevenLabsConfigured() {
  const cfg = getElevenLabsConfig();
  if (!cfg.apiKey) {
    const err = new Error('elevenlabs_not_configured');
    err.code = 'elevenlabs_not_configured';
    throw err;
  }
  return cfg;
}

module.exports = {
  getElevenLabsConfig,
  assertElevenLabsConfigured,
  loadDotEnvOnce,
};
