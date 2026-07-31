const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { sendOtpFlow, verifyOtpFlow, loginCustomerFlow } = require('./sms_otp');
const {
  handleCreatePhoneOrder,
  handleLookupPhoneCustomer,
  handlePhoneCallInit,
  handlePhoneCallEnded,
  handleListFailedPhoneOrders,
  handleUpdateFailedPhoneOrder,
  handleCancelPhoneOrder,
  handleInquirePhoneOrder,
  handleListPhoneCallLogs,
  handleImportPhoneCustomers,
  handleListPhoneCustomers,
  handleUpdatePhoneCustomer,
  handleDeletePhoneCustomer,
} = require('./phone_order');
const {
  handleGetPhoneAiTraining,
  handleSavePhoneAiTraining,
  handleSyncPhoneAiAgent,
} = require('./phone_ai_training');
const { loadDotEnvOnce } = require('./elevenlabs_config');

loadDotEnvOnce();
admin.initializeApp();

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

function readJsonBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  return {};
}

async function handleSendOtp(req, res, logName) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    const body = readJsonBody(req);
    const result = await sendOtpFlow(body.phone, {
      forRegistration: body.for_registration !== false,
    });
    res.status(200).json(result);
  } catch (e) {
    const code = e.code || 'otp_send_failed';
    const status =
      code === 'otp_rate_limited'
        ? 429
        : code === 'invalid_phone' || code === 'phone_already_registered'
          ? 400
          : code === 'sms_not_configured' ||
              code === 'sms_header_invalid' ||
              code === 'sms_auth_failed'
            ? 503
            : code === 'sms_send_failed'
              ? 502
              : 500;
    console.error(logName, code, e.message);
    res.status(status).json({ error: code });
  }
}

async function handleVerifyOtp(req, res, logName) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    const body = readJsonBody(req);
    const result = await verifyOtpFlow({
      rawPhone: body.phone,
      code: body.code,
      name: body.name,
      password: body.password,
    });
    res.status(200).json(result);
  } catch (e) {
    const code = e.code || 'invalid_otp';
    const status =
      code === 'otp_expired' ||
      code === 'otp_locked' ||
      code === 'invalid_otp' ||
      code === 'invalid_password' ||
      code === 'phone_already_registered'
        ? 400
        : 500;
    console.error(logName, code, e.message);
    res.status(status).json({ error: code });
  }
}

async function handleLoginCustomer(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    const body = readJsonBody(req);
    const result = await loginCustomerFlow({
      rawPhone: body.phone,
      password: body.password,
    });
    res.status(200).json(result);
  } catch (e) {
    const code = e.code || 'invalid_credentials';
    console.error('loginCustomer', code, e.message);
    res.status(401).json({ error: code });
  }
}

/** Müşteri: kayıtta SMS OTP; girişte telefon+şifre */
exports.sendSmsOtp = functions.https.onRequest((req, res) =>
  handleSendOtp(req, res, 'sendSmsOtp'),
);
exports.verifySmsOtp = functions.https.onRequest((req, res) =>
  handleVerifyOtp(req, res, 'verifySmsOtp'),
);
exports.loginCustomer = functions.https.onRequest((req, res) =>
  handleLoginCustomer(req, res),
);

/** Eski WhatsApp endpoint adları → aynı SMS akışı (geriye uyum) */
exports.sendWhatsAppOtp = functions.https.onRequest((req, res) =>
  handleSendOtp(req, res, 'sendWhatsAppOtp'),
);
exports.verifyWhatsAppOtp = functions.https.onRequest((req, res) =>
  handleVerifyOtp(req, res, 'verifyWhatsAppOtp'),
);

/** QR menü: ürün + ekstra + ayarlar (tarayıcı API key kısıtı bypass) */
exports.getQrMenuPublic = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET' && req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    const db = admin.firestore();
    const [settingsSnap, productsSnap, extrasSnap] = await Promise.all([
      db.doc('meta/qr_menu_settings').get(),
      db.collection('products').get(),
      db.collection('catalog_extras').get(),
    ]);

    const settings = settingsSnap.exists
      ? { id: settingsSnap.id, ...settingsSnap.data() }
      : {
          title: 'Tost-u Şahane',
          welcome_note: 'Lezzetler sofranıza gelsin.',
          enabled: true,
          categories: {},
          hidden_product_ids: [],
          product_display_order: [],
        };

    const products = productsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    const extras = extrasSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

    res.set('Cache-Control', 'public, max-age=30');
    res.status(200).json({ settings, products, extras });
  } catch (e) {
    console.error('getQrMenuPublic', e);
    res.status(500).json({ error: 'menu_load_failed' });
  }
});

/** Telefon AI: sipariş oluştur + müşteri lookup / import */
exports.createPhoneOrder = functions.https.onRequest((req, res) =>
  handleCreatePhoneOrder(req, res),
);
exports.lookupPhoneCustomer = functions.https.onRequest((req, res) =>
  handleLookupPhoneCustomer(req, res),
);
/** Arama bağlanır bağlanmaz müşteri dyn vars (ElevenLabs initiation webhook) */
exports.phoneCallInit = functions.https.onRequest((req, res) =>
  handlePhoneCallInit(req, res),
);
/** Arama bitince başarısız sipariş (post-call transcript webhook) */
exports.phoneCallEnded = functions.https.onRequest((req, res) =>
  handlePhoneCallEnded(req, res),
);
exports.listFailedPhoneOrders = functions.https.onRequest((req, res) =>
  handleListFailedPhoneOrders(req, res),
);
exports.updateFailedPhoneOrder = functions.https.onRequest((req, res) =>
  handleUpdateFailedPhoneOrder(req, res),
);
exports.cancelPhoneOrder = functions.https.onRequest((req, res) =>
  handleCancelPhoneOrder(req, res),
);
exports.inquirePhoneOrder = functions.https.onRequest((req, res) =>
  handleInquirePhoneOrder(req, res),
);
exports.listPhoneCallLogs = functions.https.onRequest((req, res) =>
  handleListPhoneCallLogs(req, res),
);
exports.importPhoneCustomers = functions.https.onRequest((req, res) =>
  handleImportPhoneCustomers(req, res),
);
exports.listPhoneCustomers = functions.https.onRequest((req, res) =>
  handleListPhoneCustomers(req, res),
);
exports.updatePhoneCustomer = functions.https.onRequest((req, res) =>
  handleUpdatePhoneCustomer(req, res),
);
exports.deletePhoneCustomer = functions.https.onRequest((req, res) =>
  handleDeletePhoneCustomer(req, res),
);

/** Telefon AI eğitimi (yönetici örnekleri → ElevenLabs prompt sync) */
exports.getPhoneAiTraining = functions.https.onRequest((req, res) =>
  handleGetPhoneAiTraining(req, res),
);
exports.savePhoneAiTraining = functions.https.onRequest((req, res) =>
  handleSavePhoneAiTraining(req, res),
);
exports.syncPhoneAiAgent = functions.https.onRequest((req, res) =>
  handleSyncPhoneAiAgent(req, res),
);

/** QR menüden: garson çağır / hesap iste */
exports.createTableServiceRequest = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    const body = readJsonBody(req);
    const branchId = String(body.branchId || 'branch_1').trim();
    const tableNumber = Number(body.tableNumber);
    const type = String(body.type || '').trim();
    if (!Number.isFinite(tableNumber) || tableNumber < 1 || tableNumber > 200) {
      res.status(400).json({ error: 'invalid_table' });
      return;
    }
    if (type !== 'call_waiter' && type !== 'request_bill') {
      res.status(400).json({ error: 'invalid_type' });
      return;
    }

    const db = admin.firestore();
    const recent = await db
      .collection('table_service_requests')
      .where('branch_id', '==', branchId)
      .where('table_number', '==', tableNumber)
      .where('type', '==', type)
      .where('status', '==', 'pending')
      .limit(5)
      .get();

    const now = Date.now();
    for (const doc of recent.docs) {
      const created = doc.data().created_at;
      const ms = created && created.toMillis ? created.toMillis() : 0;
      if (ms && now - ms < 60 * 1000) {
        res.status(429).json({ error: 'rate_limited', id: doc.id });
        return;
      }
    }

    const message =
      type === 'call_waiter'
        ? `${tableNumber} numaralı masa garson çağırıyor`
        : `${tableNumber} numaralı masa hesap istiyor`;

    const ref = await db.collection('table_service_requests').add({
      branch_id: branchId,
      table_number: tableNumber,
      type,
      status: 'pending',
      message,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(200).json({ ok: true, id: ref.id, message });
  } catch (e) {
    console.error('createTableServiceRequest', e);
    res.status(500).json({ error: 'request_failed' });
  }
});


const STATUS_TR = {
  received: 'Sipariş Alındı',
  preparing: 'Hazırlanıyor',
  ready: 'Hazır',
  waitingCourier: 'Kurye Bekliyor',
  onTheWay: 'Yolda',
  delivered: 'Teslim Edildi',
  cancelled: 'İptal Edildi',
};

function statusLabelTr(status) {
  return STATUS_TR[status] || status;
}

exports.onOrderUpdate = functions.firestore
  .document('orders/{orderId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return null;

    const status = after.status;
    const branchId = after.branch_id;
    const customerId = after.customer_id;
    const orderNumber = after.order_number;
    const orderType = after.order_type || 'delivery';

    const tokens = [];
    const usersSnap = await admin.firestore().collection('users').get();
    usersSnap.forEach((doc) => {
      const data = doc.data();
      const token = data.fcm_token;
      if (!token) return;
      const role = data.role;
      const userBranch = data.branch_id;

      if (role === 'branchManager' && userBranch === branchId) {
        if (orderType !== 'dineIn') {
          tokens.push(token);
        }
      } else if (
        role === 'courier' &&
        status === 'waitingCourier' &&
        userBranch === branchId
      ) {
        tokens.push(token);
      } else if (doc.id === customerId) {
        tokens.push(token);
      }
    });

    if (tokens.length === 0) return null;

    return admin.messaging().sendEachForMulticast({
      tokens: [...new Set(tokens)],
      notification: {
        title: 'Tostu Şahane',
        body: `Sipariş #${orderNumber} — ${statusLabelTr(status)}`,
      },
      data: {
        type: 'order_update',
        order_id: context.params.orderId,
        status: status,
        order_type: orderType,
      },
    });
  });
