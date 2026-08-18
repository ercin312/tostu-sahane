/**
 * PayTR iFrame API — STEP 2 bildirim (callback) URL.
 * PayTR bu endpoint'e POST atar; yanıt gövdesi mutlaka "OK" olmalı.
 *
 * Mağaza Paneli → Destek & Kurulum → Bildirim URL:
 *   https://us-central1-tostusahane-e4e71.cloudfunctions.net/paytrCallback
 *
 * WooCommerce siparişleri (merchant_oid içinde PAYTRWOO) site callback'ine iletilir.
 */

const crypto = require('crypto');
const admin = require('firebase-admin');

const WC_PAYTR_CALLBACK_URL =
  process.env.WOOCOMMERCE_PAYTR_CALLBACK_URL ||
  'https://www.tostusahane.com/index.php?wc-api=wc_gateway_paytrcheckout';

function readFormBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  return {};
}

async function loadPaytrSecrets() {
  const snap = await admin.firestore().doc('meta/paytr_settings').get();
  const data = snap.exists ? snap.data() || {} : {};
  const merchantKey = String(data.merchant_key || '').trim();
  const merchantSalt = String(data.merchant_salt || '').trim();
  if (!merchantKey || !merchantSalt) {
    throw new Error('paytr_secrets_missing');
  }
  return { merchantKey, merchantSalt };
}

async function forwardToWooCommerce(body) {
  const merchantOid = String(body.merchant_oid || '');
  if (!merchantOid.includes('PAYTRWOO')) return;

  try {
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(body)) {
      if (value == null) continue;
      params.append(key, String(value));
    }
    const res = await fetch(WC_PAYTR_CALLBACK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });
    const text = await res.text();
    console.log('paytrCallback WC forward', {
      merchantOid,
      status: res.status,
      body: String(text).slice(0, 80),
    });
  } catch (e) {
    console.error('paytrCallback WC forward failed', e.message);
  }
}

/**
 * @param {import('firebase-functions').https.Request} req
 * @param {import('firebase-functions').Response} res
 */
async function handlePaytrCallback(req, res) {
  if (req.method === 'GET') {
    res.status(200).send('paytrCallback ok');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).send('method_not_allowed');
    return;
  }

  const body = readFormBody(req);
  const merchantOid = String(body.merchant_oid || '').trim();
  const status = String(body.status || '').trim();
  const totalAmount = String(body.total_amount || '').trim();
  const hash = String(body.hash || '').trim();

  if (!merchantOid || !status || !totalAmount || !hash) {
    console.error('paytrCallback missing fields', {
      merchantOid: !!merchantOid,
      status: !!status,
      totalAmount: !!totalAmount,
      hash: !!hash,
    });
    res.status(400).send('bad_request');
    return;
  }

  let merchantKey;
  let merchantSalt;
  try {
    ({ merchantKey, merchantSalt } = await loadPaytrSecrets());
  } catch (e) {
    console.error('paytrCallback secrets', e.message);
    res.status(500).send('config_error');
    return;
  }

  const expected = crypto
    .createHmac('sha256', merchantKey)
    .update(merchantOid + merchantSalt + status + totalAmount)
    .digest('base64');

  if (expected !== hash) {
    console.error('paytrCallback bad hash', { merchantOid });
    res.status(400).send('bad_hash');
    return;
  }

  const ref = admin.firestore().collection('paytr_payments').doc(merchantOid);
  const existing = await ref.get();
  if (!(existing.exists && existing.data()?.processed === true)) {
    await ref.set(
      {
        merchant_oid: merchantOid,
        status,
        total_amount: totalAmount,
        payment_type: body.payment_type || null,
        currency: body.currency || 'TL',
        test_mode: body.test_mode || null,
        processed: true,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        created_at:
          existing.exists && existing.data()?.created_at
            ? existing.data().created_at
            : admin.firestore.FieldValue.serverTimestamp(),
        raw: {
          failed_reason_code: body.failed_reason_code || null,
          failed_reason_msg: body.failed_reason_msg || null,
        },
      },
      { merge: true },
    );
  }

  await forwardToWooCommerce(body);

  console.log('paytrCallback processed', { merchantOid, status, totalAmount });
  res.status(200).send('OK');
}

module.exports = { handlePaytrCallback };
