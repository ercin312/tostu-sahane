/**
 * WooCommerce (tostusahane.com/siparis-ver) → Firestore orders.
 * Windows şube uygulaması aynı orders koleksiyonunu dinler.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const DEFAULT_BRANCH_ID = 'branch_1';

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, X-Tostu-Webhook-Secret, X-WC-Webhook-Signature',
  );
}

function readJsonBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  return {};
}

function webhookSecret() {
  return (
    process.env.WOOCOMMERCE_WEBHOOK_SECRET ||
    (functions.config().woocommerce &&
      functions.config().woocommerce.webhook_secret) ||
    ''
  );
}

function assertSecret(req) {
  const expected = String(webhookSecret() || '').trim();
  if (!expected) {
    const err = new Error('webhook_secret_not_configured');
    err.code = 'webhook_secret_not_configured';
    throw err;
  }
  const provided = String(
    req.get('x-tostu-webhook-secret') ||
      req.get('X-Tostu-Webhook-Secret') ||
      req.query.secret ||
      '',
  ).trim();
  if (!provided || provided !== expected) {
    const err = new Error('unauthorized');
    err.code = 'unauthorized';
    throw err;
  }
}

async function nextOrderNumber(db) {
  const ref = db.collection('meta').doc('order_counter');
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = (snap.data() && snap.data().value) || 1000;
    const next = Number(current) + 1;
    tx.set(ref, { value: next }, { merge: true });
    return next;
  });
}

function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

function formatTrPhone(raw) {
  let d = digitsOnly(raw);
  if (d.startsWith('90') && d.length >= 12) d = d.slice(2);
  if (d.startsWith('0') && d.length >= 11) d = d.slice(1);
  if (d.length === 10) {
    return `0${d.slice(0, 3)} ${d.slice(3, 6)} ${d.slice(6, 8)} ${d.slice(8)}`;
  }
  return String(raw || '').trim() || null;
}

function mapPaymentMethod(wcMethodId, wcMethodTitle) {
  const id = String(wcMethodId || '').toLowerCase();
  const title = String(wcMethodTitle || '').toLowerCase();
  if (
    id.includes('cod') ||
    id.includes('cash') ||
    title.includes('kapıda nakit') ||
    title.includes('nakit')
  ) {
    return 'cashOnDelivery';
  }
  if (
    id.includes('paytr') ||
    id.includes('stripe') ||
    id.includes('iyzico') ||
    id.includes('card') ||
    title.includes('kart') ||
    title.includes('kredi')
  ) {
    // Site online tahsil ettiyse online; kapıda kart ayrı WC method olabilir.
    if (title.includes('kapıda') && title.includes('kart')) {
      return 'cardOnDelivery';
    }
    return 'onlineCard';
  }
  if (title.includes('kapıda')) return 'cashOnDelivery';
  return 'cashOnDelivery';
}

function buildAddress(order) {
  const shipping = order.shipping || {};
  const billing = order.billing || {};
  const parts = [
    shipping.address_1 || billing.address_1,
    shipping.address_2 || billing.address_2,
    shipping.city || billing.city,
    shipping.state || billing.state,
    shipping.postcode || billing.postcode,
  ]
    .map((p) => String(p || '').trim())
    .filter(Boolean);
  if (parts.length) return parts.join(', ');
  return 'Web sipariş — adres yok';
}

function mapLineItems(lineItems) {
  const items = Array.isArray(lineItems) ? lineItems : [];
  return items.map((line, index) => {
    const name = String(line.name || line.product_name || 'Ürün').trim();
    const qty = Math.max(1, Number(line.quantity) || 1);
    const total = Number(line.total);
    const subtotal = Number(line.subtotal);
    const unitFromTotal =
      Number.isFinite(total) && qty > 0 ? total / qty : NaN;
    const unitFromSub =
      Number.isFinite(subtotal) && qty > 0 ? subtotal / qty : NaN;
    const unitPrice = Number.isFinite(unitFromTotal)
      ? unitFromTotal
      : Number.isFinite(unitFromSub)
        ? unitFromSub
        : Number(line.price) || 0;

    const meta = [];
    const metaData = Array.isArray(line.meta_data) ? line.meta_data : [];
    for (const m of metaData) {
      const key = String(m.key || m.display_key || '').trim();
      if (!key || key.startsWith('_')) continue;
      const val = String(m.value || m.display_value || '').trim();
      if (!val) continue;
      meta.push(`${key}: ${val}`);
    }

    const productId = String(
      line.sku || line.product_id || line.variation_id || `wc_${index}`,
    );

    return {
      id: `wc_item_${line.id || index}`,
      product_id: productId,
      product_name_key: name,
      unit_price: Math.round(unitPrice * 100) / 100,
      quantity: qty,
      selected_options: meta,
      note: meta.length ? meta.join(' · ') : null,
    };
  });
}

function customerNameFromOrder(order) {
  const billing = order.billing || {};
  const first = String(billing.first_name || '').trim();
  const last = String(billing.last_name || '').trim();
  const full = `${first} ${last}`.trim();
  if (full) return full;
  if (billing.company) return String(billing.company).trim();
  return 'Web müşteri';
}

/**
 * Accepts either:
 * - WooCommerce webhook payload (order object at root, or { id, ... })
 * - Our mu-plugin payload { woo_order_id, order: {...} }
 */
async function upsertWebOrderFromWoo(orderPayload) {
  const db = admin.firestore();
  const order =
    orderPayload && orderPayload.order && typeof orderPayload.order === 'object'
      ? orderPayload.order
      : orderPayload;

  const wooId = Number(
    orderPayload.woo_order_id ||
      order.id ||
      order.number ||
      orderPayload.id ||
      0,
  );
  if (!wooId) {
    const err = new Error('woo_order_id_required');
    err.code = 'woo_order_id_required';
    throw err;
  }

  const status = String(order.status || '').toLowerCase();
  if (status === 'cancelled' || status === 'failed' || status === 'refunded') {
    return { skipped: true, reason: 'ignored_status', status, wooId };
  }

  const docId = `web_wc_${wooId}`;
  const existingRef = db.collection('orders').doc(docId);
  const existingSnap = await existingRef.get();
  if (existingSnap.exists) {
    return {
      skipped: true,
      reason: 'already_imported',
      orderId: docId,
      orderNumber: existingSnap.data().order_number,
    };
  }

  const items = mapLineItems(order.line_items);
  if (!items.length) {
    const err = new Error('items_required');
    err.code = 'items_required';
    throw err;
  }

  const branchId =
    String(
      orderPayload.branch_id ||
        order.branch_id ||
        process.env.WEB_ORDER_BRANCH_ID ||
        DEFAULT_BRANCH_ID,
    ).trim() || DEFAULT_BRANCH_ID;

  const orderNumber = await nextOrderNumber(db);
  const now = new Date().toISOString();
  const phoneRaw =
    (order.billing && order.billing.phone) ||
    order.customer_phone ||
    orderPayload.customer_phone ||
    '';
  const phoneDisplay = formatTrPhone(phoneRaw);
  const phoneDigits = digitsOnly(phoneRaw);
  const ten =
    phoneDigits.length >= 10 ? phoneDigits.slice(-10) : phoneDigits;

  const shippingTotal = Number(order.shipping_total) || 0;
  const discountTotal = Number(order.discount_total) || 0;
  const totalAmount = Number(order.total);
  const computedTotal = items.reduce(
    (sum, it) => sum + it.unit_price * it.quantity,
    0,
  );

  const paymentMethod = mapPaymentMethod(
    order.payment_method,
    order.payment_method_title,
  );

  const customerName = customerNameFromOrder(order);
  const address = buildAddress(order);
  const customerNote = String(order.customer_note || '').trim();
  const orderNoteParts = [
    `Web #${wooId}`,
    customerNote || null,
    order.payment_method_title
      ? `Ödeme: ${order.payment_method_title}`
      : null,
  ].filter(Boolean);

  const doc = {
    id: docId,
    order_number: orderNumber,
    customer_id: ten ? `web_0${ten}` : `web_wc_${wooId}`,
    customer_name: customerName,
    branch_id: branchId,
    items: items.map((it) => {
      const out = { ...it };
      if (!out.note) delete out.note;
      return out;
    }),
    total_amount: Number.isFinite(totalAmount)
      ? totalAmount
      : Math.round((computedTotal + shippingTotal - discountTotal) * 100) /
        100,
    status: 'received',
    created_at: now,
    updated_at: now,
    address,
    payment_method: paymentMethod,
    customer_phone: phoneDisplay,
    customer_phone_digits: ten || null,
    delivery_now: true,
    order_type: 'delivery',
    is_pickup: false,
    is_table_addon: false,
    order_source: 'web',
    woo_order_id: wooId,
    woo_order_number: String(order.number || wooId),
    discount_amount: discountTotal,
    delivery_fee_amount: shippingTotal,
    status_timestamps: { received: now },
    approach_notification_sent: false,
    preparation_tags: [],
    order_note: orderNoteParts.join(' · '),
  };

  if (order.transaction_id) {
    doc.payment_transaction_id = String(order.transaction_id);
  }

  Object.keys(doc).forEach((k) => {
    if (doc[k] == null) delete doc[k];
  });

  await existingRef.set(doc, { merge: false });

  console.log('woocommerceOrder imported', {
    docId,
    orderNumber,
    wooId,
    items: items.length,
    total: doc.total_amount,
  });

  return {
    skipped: false,
    orderId: docId,
    orderNumber,
    wooId,
  };
}

async function handleWooCommerceOrderWebhook(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method === 'GET') {
    res.status(200).json({ ok: true, service: 'woocommerceOrderWebhook' });
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  try {
    assertSecret(req);
    const topic = String(
      req.get('x-wc-webhook-topic') || req.get('X-WC-Webhook-Topic') || '',
    ).toLowerCase();
    if (topic.includes('deleted') || topic.includes('trashed')) {
      res.status(200).json({ ok: true, skipped: true, reason: 'deleted_topic' });
      return;
    }

    const body = readJsonBody(req);
    // WooCommerce sometimes sends webhook.delivery_id ping with empty id
    if (body && body.webhook_id && !body.id && !body.line_items) {
      res.status(200).json({ ok: true, ping: true });
      return;
    }

    const result = await upsertWebOrderFromWoo(body);
    res.status(200).json({ ok: true, ...result });
  } catch (e) {
    const code = e.code || 'import_failed';
    const status =
      code === 'unauthorized'
        ? 401
        : code === 'webhook_secret_not_configured'
          ? 503
          : code === 'woo_order_id_required' || code === 'items_required'
            ? 400
            : 500;
    console.error('woocommerceOrderWebhook', code, e.message);
    res.status(status).json({ error: code });
  }
}

module.exports = {
  handleWooCommerceOrderWebhook,
  upsertWebOrderFromWoo,
};
