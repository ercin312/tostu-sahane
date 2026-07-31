const crypto = require('crypto');
const admin = require('firebase-admin');
const functions = require('firebase-functions');

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_MS = 60 * 1000;

function whatsappConfig() {
  const cfg = functions.config().whatsapp || {};
  return {
    token: process.env.WHATSAPP_TOKEN || cfg.token,
    phoneNumberId: process.env.WHATSAPP_PHONE_NUMBER_ID || cfg.phone_number_id,
    template:
      process.env.WHATSAPP_OTP_TEMPLATE || cfg.otp_template || 'otp_verification',
    language:
      process.env.WHATSAPP_OTP_TEMPLATE_LANG || cfg.otp_template_lang || 'tr',
  };
}

function normalizePhone(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (digits.startsWith('0') && digits.length === 11) {
    digits = `90${digits.slice(1)}`;
  }
  if (digits.length === 10 && digits.startsWith('5')) {
    digits = `90${digits}`;
  }
  return digits;
}

function hashOtp(code, salt) {
  return crypto.createHash('sha256').update(`${salt}:${code}`).digest('hex');
}

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function sendWhatsAppTemplate(toE164, code) {
  const { token, phoneNumberId, template, language } = whatsappConfig();

  if (!token || !phoneNumberId) {
    const err = new Error('whatsapp_not_configured');
    err.code = 'whatsapp_not_configured';
    throw err;
  }

  const body = {
    messaging_product: 'whatsapp',
    to: toE164,
    type: 'template',
    template: {
      name: template,
      language: { code: language },
      components: [
        {
          type: 'body',
          parameters: [{ type: 'text', text: code }],
        },
        {
          type: 'button',
          sub_type: 'url',
          index: '0',
          parameters: [{ type: 'text', text: code }],
        },
      ],
    },
  };

  const response = await fetch(
    `https://graph.facebook.com/v19.0/${phoneNumberId}/messages`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    console.error('WhatsApp send failed', response.status, text);
    const err = new Error('whatsapp_send_failed');
    err.code = 'whatsapp_send_failed';
    throw err;
  }
}

async function createOrUpdateChallenge(phone, code) {
  const db = admin.firestore();
  const ref = db.collection('otp_challenges').doc(phone);
  const salt = crypto.randomBytes(16).toString('hex');
  const now = Date.now();
  await ref.set({
    phone,
    code_hash: hashOtp(code, salt),
    salt,
    expires_at: now + OTP_TTL_MS,
    attempts: 0,
    created_at: now,
    last_sent_at: now,
  });
}

async function assertCanSend(phone) {
  const db = admin.firestore();
  const snap = await db.collection('otp_challenges').doc(phone).get();
  if (!snap.exists) return;
  const data = snap.data() || {};
  const last = data.last_sent_at || 0;
  if (Date.now() - last < RESEND_COOLDOWN_MS) {
    const err = new Error('otp_rate_limited');
    err.code = 'otp_rate_limited';
    throw err;
  }
}

/**
 * @returns {{ ok: true } | never}
 */
async function sendOtpFlow(rawPhone) {
  const phone = normalizePhone(rawPhone);
  if (phone.length < 11) {
    const err = new Error('invalid_phone');
    err.code = 'invalid_phone';
    throw err;
  }

  await assertCanSend(phone);
  const code = generateOtp();
  await createOrUpdateChallenge(phone, code);
  await sendWhatsAppTemplate(phone, code);
  return { ok: true, phone };
}

/**
 * Verifies OTP and upserts customer user document.
 * @returns {{ user: object }}
 */
async function verifyOtpFlow({ rawPhone, code, name }) {
  const phone = normalizePhone(rawPhone);
  const otp = String(code || '').trim();
  if (phone.length < 11 || otp.length !== 6) {
    const err = new Error('invalid_otp');
    err.code = 'invalid_otp';
    throw err;
  }

  const db = admin.firestore();
  const ref = db.collection('otp_challenges').doc(phone);
  const snap = await ref.get();
  if (!snap.exists) {
    const err = new Error('invalid_otp');
    err.code = 'invalid_otp';
    throw err;
  }

  const data = snap.data() || {};
  if ((data.attempts || 0) >= MAX_ATTEMPTS) {
    await ref.delete();
    const err = new Error('otp_locked');
    err.code = 'otp_locked';
    throw err;
  }
  if (Date.now() > (data.expires_at || 0)) {
    await ref.delete();
    const err = new Error('otp_expired');
    err.code = 'otp_expired';
    throw err;
  }

  const expected = hashOtp(otp, data.salt || '');
  if (expected !== data.code_hash) {
    await ref.update({ attempts: (data.attempts || 0) + 1 });
    const err = new Error('invalid_otp');
    err.code = 'invalid_otp';
    throw err;
  }

  await ref.delete();

  const users = db.collection('users');
  const existing = await users.where('phone', '==', phone).limit(1).get();
  const displayName =
    (name && String(name).trim()) ||
    (existing.empty ? 'Müşteri' : existing.docs[0].data().name) ||
    'Müşteri';

  let userId;
  if (!existing.empty) {
    userId = existing.docs[0].id;
    await users.doc(userId).set(
      {
        phone,
        name: displayName,
        role: 'customer',
        phone_verified_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  } else {
    userId = `customer_${phone}`;
    await users.doc(userId).set({
      phone,
      name: displayName,
      role: 'customer',
      phone_verified_at: admin.firestore.FieldValue.serverTimestamp(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return {
    user: {
      id: userId,
      name: displayName,
      role: 'customer',
      phone,
      access_token: 'firestore_token',
      refresh_token: 'firestore_refresh',
    },
  };
}

module.exports = {
  normalizePhone,
  sendOtpFlow,
  verifyOtpFlow,
  hashOtp,
};
