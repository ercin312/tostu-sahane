const crypto = require('crypto');
const admin = require('firebase-admin');
const functions = require('firebase-functions');

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_MS = 60 * 1000;

/**
 * Netgsm OTP SMS.
 * Endpoint: https://api.netgsm.com.tr/sms/send/otp
 *
 * Env (önerilen):
 *   NETGSM_SMS_USERCODE  — abone no (örn. 8503028334)
 *   NETGSM_SMS_PASSWORD  — API alt kullanıcı şifresi
 *   NETGSM_SMS_HEADER    — onaylı gönderici adı (msgheader)
 *
 * Geriye dönük: SMS_USERNAME / SMS_PASSWORD / SMS_SENDER
 */
function smsConfig() {
  const cfg = functions.config().sms || {};
  const netgsm = functions.config().netgsm || {};
  const phoneRaw =
    process.env.NETGSM_PHONE ||
    process.env.NETGSM_SMS_USERCODE ||
    netgsm.phone ||
    '';
  // +908503028334 → 8503028334 (abone / usercode)
  let phoneAsUsercode = String(phoneRaw).replace(/\D/g, '');
  if (phoneAsUsercode.startsWith('90') && phoneAsUsercode.length >= 12) {
    phoneAsUsercode = phoneAsUsercode.slice(2);
  }
  if (phoneAsUsercode.startsWith('0') && phoneAsUsercode.length === 11) {
    phoneAsUsercode = phoneAsUsercode.slice(1);
  }

  // Gönderici: özel başlık yoksa abone no (850…) — marka adı zorunlu değil.
  // Netgsm’de bu numaranın “gönderici adı” olarak onaylı olması gerekir.
  const resolvedUsercode =
    process.env.NETGSM_SMS_USERCODE ||
    process.env.SMS_USERNAME ||
    process.env.NETGSM_USERCODE ||
    cfg.usercode ||
    cfg.username ||
    netgsm.usercode ||
    phoneAsUsercode ||
    '';

  return {
    usercode: resolvedUsercode,
    password:
      process.env.NETGSM_SMS_PASSWORD ||
      process.env.SMS_PASSWORD ||
      process.env.NETGSM_PASSWORD ||
      cfg.password ||
      netgsm.password ||
      '',
    msgheader:
      process.env.NETGSM_SMS_HEADER ||
      process.env.SMS_SENDER ||
      process.env.NETGSM_HEADER ||
      cfg.sender ||
      cfg.msgheader ||
      netgsm.header ||
      resolvedUsercode,
    endpoint:
      process.env.NETGSM_SMS_ENDPOINT ||
      process.env.SMS_ENDPOINT ||
      'https://api.netgsm.com.tr/sms/send/otp',
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

/** Netgsm OTP: 5xxxxxxxxx (10 hane, başında 0/90 yok) */
function toNetgsmOtpDest(phoneE164) {
  let d = String(phoneE164 || '').replace(/\D/g, '');
  if (d.startsWith('90') && d.length >= 12) d = d.slice(2);
  if (d.startsWith('0') && d.length === 11) d = d.slice(1);
  return d;
}

function hashOtp(code, salt) {
  return crypto.createHash('sha256').update(`${salt}:${code}`).digest('hex');
}

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function escapeXml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function parseNetgsmOtpCode(text) {
  const raw = String(text || '').trim();
  const xmlCode = raw.match(/<code>\s*([^<]+)\s*<\/code>/i);
  if (xmlCode) return String(xmlCode[1]).trim();
  // Bazen düz "00" / "0" döner
  const firstToken = raw.split(/\s+/)[0];
  if (/^\d+$/.test(firstToken)) return firstToken;
  return raw;
}

async function sendSmsOtp(toE164, code) {
  const { usercode, password, msgheader, endpoint } = smsConfig();
  if (!usercode || !password) {
    const err = new Error('sms_not_configured');
    err.code = 'sms_not_configured';
    throw err;
  }

  const dest = toNetgsmOtpDest(toE164);
  if (!/^5\d{9}$/.test(dest)) {
    const err = new Error('invalid_phone');
    err.code = 'invalid_phone';
    throw err;
  }

  const message = `Tost-u Sahane dogrulama kodunuz: ${code}. 5 dk gecerlidir.`;
  const xml = `<?xml version="1.0"?>
<mainbody>
  <header>
    <usercode>${escapeXml(usercode)}</usercode>
    <password>${escapeXml(password)}</password>
    <msgheader>${escapeXml(msgheader)}</msgheader>
  </header>
  <body>
    <msg><![CDATA[${message}]]></msg>
    <no>${escapeXml(dest)}</no>
  </body>
</mainbody>`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/xml' },
    body: xml,
  });

  const text = await response.text();
  const resultCode = parseNetgsmOtpCode(text);
  // 0 / 00 = başarı (Netgsm OTP)
  if (resultCode === '0' || resultCode === '00') {
    return;
  }

  console.error('Netgsm OTP send failed', {
    status: response.status,
    resultCode,
    body: text.slice(0, 500),
  });
  const err = new Error('sms_send_failed');
  err.code =
    resultCode === '40'
      ? 'sms_header_invalid'
      : resultCode === '30'
        ? 'sms_auth_failed'
        : 'sms_send_failed';
  err.detail = resultCode;
  throw err;
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
    channel: 'sms',
    provider: 'netgsm',
  });
}

function hashPassword(password, salt) {
  return crypto.createHash('sha256').update(`${salt}:${password}`).digest('hex');
}

function phoneVariants(phone) {
  return [phone, `0${phone.slice(2)}`, `+${phone}`, phone.slice(2)];
}

async function findCustomerByPhone(phone) {
  const users = admin.firestore().collection('users');
  for (const p of phoneVariants(phone)) {
    const snap = await users.where('phone', '==', p).limit(1).get();
    if (!snap.empty) return snap.docs[0];
  }
  // Doc id convention: customer_90xxxxxxxxxx
  const byId = await users.doc(`customer_${phone}`).get();
  if (byId.exists) return byId;
  return null;
}

function userHasPassword(data) {
  if (!data) return false;
  if (data.password_hash && data.password_salt) return true;
  if (typeof data.password === 'string' && data.password.trim()) return true;
  return false;
}

function passwordMatches(data, password) {
  const trimmed = String(password || '').trim();
  if (!trimmed || !data) return false;
  if (data.password_hash && data.password_salt) {
    return hashPassword(trimmed, data.password_salt) === data.password_hash;
  }
  // Legacy plain password (ops-style)
  return (data.password || '').trim() === trimmed;
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

/** SMS OTP yalnızca yeni kayıt (numara teyidi). Şifreli hesap varsa girişe yönlendir. */
async function sendOtpFlow(rawPhone, { forRegistration = true } = {}) {
  const phone = normalizePhone(rawPhone);
  if (phone.length < 12) {
    const err = new Error('invalid_phone');
    err.code = 'invalid_phone';
    throw err;
  }

  if (forRegistration) {
    const existing = await findCustomerByPhone(phone);
    if (existing && userHasPassword(existing.data())) {
      const err = new Error('phone_already_registered');
      err.code = 'phone_already_registered';
      throw err;
    }
  }

  await assertCanSend(phone);
  const code = generateOtp();
  await createOrUpdateChallenge(phone, code);
  await sendSmsOtp(phone, code);
  return { ok: true, phone };
}

async function verifyOtpFlow({ rawPhone, code, name, password }) {
  const phone = normalizePhone(rawPhone);
  const otp = String(code || '').trim();
  const passwordTrimmed = String(password || '').trim();
  if (phone.length < 12 || otp.length !== 6) {
    const err = new Error('invalid_otp');
    err.code = 'invalid_otp';
    throw err;
  }
  if (passwordTrimmed.length < 6) {
    const err = new Error('invalid_password');
    err.code = 'invalid_password';
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

  const existing = await findCustomerByPhone(phone);
  if (existing && userHasPassword(existing.data())) {
    const err = new Error('phone_already_registered');
    err.code = 'phone_already_registered';
    throw err;
  }

  const displayName =
    (name && String(name).trim()) ||
    (existing ? existing.data().name : null) ||
    'Müşteri';

  const salt = crypto.randomBytes(16).toString('hex');
  const password_hash = hashPassword(passwordTrimmed, salt);
  const payload = {
    phone,
    name: displayName,
    role: 'customer',
    password_hash,
    password_salt: salt,
    phone_verified_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  let userId;
  if (existing) {
    userId = existing.id;
    await db.collection('users').doc(userId).set(payload, { merge: true });
  } else {
    userId = `customer_${phone}`;
    await db.collection('users').doc(userId).set({
      ...payload,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
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

/** Kayıtlı müşteri: telefon + şifre (SMS yok). */
async function loginCustomerFlow({ rawPhone, password }) {
  const phone = normalizePhone(rawPhone);
  const passwordTrimmed = String(password || '').trim();
  if (phone.length < 12 || passwordTrimmed.length < 6) {
    const err = new Error('invalid_credentials');
    err.code = 'invalid_credentials';
    throw err;
  }

  const existing = await findCustomerByPhone(phone);
  if (!existing || existing.data().role !== 'customer') {
    const err = new Error('invalid_credentials');
    err.code = 'invalid_credentials';
    throw err;
  }
  const data = existing.data() || {};
  if (!passwordMatches(data, passwordTrimmed)) {
    const err = new Error('invalid_credentials');
    err.code = 'invalid_credentials';
    throw err;
  }

  await existing.ref.set(
    {
      phone,
      last_login_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return {
    user: {
      id: existing.id,
      name: data.name || 'Müşteri',
      role: 'customer',
      phone,
      access_token: 'firestore_token',
      refresh_token: 'firestore_refresh',
    },
  };
}

module.exports = {
  normalizePhone,
  toNetgsmOtpDest,
  sendOtpFlow,
  verifyOtpFlow,
  loginCustomerFlow,
  hashOtp,
  parseNetgsmOtpCode,
};
