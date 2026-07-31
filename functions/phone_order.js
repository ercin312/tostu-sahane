/**
 * Telefon AI (ElevenLabs Agents) → Firestore sipariş + müşteri defteri.
 *
 * phone_customers/{10hane} — numara, isim, firma, adres hafızası
 * phoneCallInit — arama başında (initiation webhook) taslak sipariş açar
 * createPhoneOrder — sipariş yazar + defteri günceller
 * lookupPhoneCustomer — arayanı bulur (önce defter)
 * importPhoneCustomers — Excel/CSV satırlarını toplu yazar
 */

const admin = require('firebase-admin');
const {
  evaluateStoreOpen,
  normalizeBusinessHours,
} = require('./phone_business_hours');

const COLLECTION = 'phone_customers';
const FAILED_COLLECTION = 'phone_failed_orders';
const SUCCESS_COLLECTION = 'phone_call_success';
const CALL_LOGS_COLLECTION = 'phone_call_logs';
const TRAINING_DOC = 'phone_ai_training';
const AGENT_ID =
  process.env.ELEVENLABS_AGENT_ID || 'agent_2201kycqaz84fraamk0gp9qxz7hv';

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Phone-Order-Secret',
  );
}

function readJsonBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  return {};
}

function digitsOnly(value) {
  return String(value || '').replace(/\D/g, '');
}

/** TR numarayı 10 haneye (5xxxxxxxxx veya 850xxxxxxx) indir. */
function normalizeTrPhone(raw) {
  let s = String(raw || '').trim();
  // SIP URI: sip:+90532...@... veya tel:+90532...
  s = s.replace(/^sip:/i, '').replace(/^tel:/i, '');
  s = s.split('@')[0];
  let d = digitsOnly(s);
  if (d.startsWith('90') && d.length >= 12) d = d.slice(2);
  if (d.startsWith('0') && d.length >= 11) d = d.slice(1);
  if (d.length === 10) return d;
  if (d.length > 10) return d.slice(-10);
  return null;
}

function formatDisplayPhone(tenDigits) {
  if (!tenDigits || tenDigits.length !== 10) return tenDigits || '';
  return `0${tenDigits.slice(0, 3)} ${tenDigits.slice(3, 6)} ${tenDigits.slice(6)}`;
}

function assertSecret(req) {
  const expected =
    process.env.PHONE_ORDER_SECRET ||
    (functionsConfigSafe().phone_order &&
      functionsConfigSafe().phone_order.secret) ||
    '';
  if (!expected) return;
  const got =
    req.get('X-Phone-Order-Secret') ||
    (req.body && req.body.secret) ||
    '';
  if (String(got) !== String(expected)) {
    const err = new Error('unauthorized');
    err.code = 'unauthorized';
    throw err;
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

function paymentMethodFromBody(raw) {
  const v = String(raw || 'cashOnDelivery').trim();
  if (v === 'cardOnDelivery' || v === 'onlineCard' || v === 'cashOnDelivery') {
    return v;
  }
  return 'cashOnDelivery';
}

function mapItems(rawItems, { allowEmpty = false } = {}) {
  if (!Array.isArray(rawItems) || rawItems.length === 0) {
    if (allowEmpty) return [];
    const err = new Error('items_required');
    err.code = 'items_required';
    throw err;
  }
  return rawItems.map((item, index) => {
    let productId = String(item.productId || item.product_id || '').trim();
    let productNameKey = String(
      item.productNameKey ||
        item.product_name_key ||
        item.productName ||
        item.name ||
        productId ||
        'ürün',
    ).trim();
    // Paket: açık ayran → kapalı ayran
    if (
      productId === 'w_acik_ayran' ||
      /açık\s*ayran|acik\s*ayran/i.test(productNameKey)
    ) {
      productId = 'w_ayran';
      productNameKey = 'AYRAN';
    }
    const unitPrice = Number(item.unitPrice ?? item.unit_price ?? 0);
    const quantity = Math.max(1, Math.floor(Number(item.quantity ?? 1)));
    if (!productId) {
      const err = new Error('invalid_item');
      err.code = 'invalid_item';
      throw err;
    }
    const line = {
      id: String(item.id || `phone_line_${index + 1}`),
      product_id: productId,
      product_name_key: productNameKey,
      unit_price: unitPrice,
      quantity,
      selected_options: Array.isArray(item.selectedOptions)
        ? item.selectedOptions
        : Array.isArray(item.selected_options)
          ? item.selected_options
          : [],
    };
    if (item.portionKey || item.portion_key) {
      line.portion_key = item.portionKey || item.portion_key;
    }
    if (item.note) line.note = String(item.note);
    return line;
  });
}

/** Telefon paket siparişinde yasak kalemler (çay vb.). */
function findBlockedPhoneDeliveryItems(items) {
  const blocked = [];
  for (const it of items || []) {
    const id = String(it.product_id || it.productId || '').trim();
    const name = String(
      it.product_name_key || it.productNameKey || it.productName || '',
    ).trim();
    if (id === 'w_cay' || (/^çay$|^cay$/i.test(name) && id !== 'w_ice_tea')) {
      blocked.push({ productId: id || 'w_cay', reason: 'tea_not_for_delivery' });
    }
  }
  return blocked;
}

function phoneCustomerRef(db, tenDigits) {
  return db.collection(COLLECTION).doc(tenDigits);
}

async function getPhoneCustomer(db, tenDigits) {
  const snap = await phoneCustomerRef(db, tenDigits).get();
  if (!snap.exists) return null;
  return { id: snap.id, ...snap.data() };
}

/**
 * Defteri güncelle / oluştur. Adres boşsa eski adresi korur.
 */
async function upsertPhoneCustomer(db, {
  tenDigits,
  name,
  company,
  address,
  deliveryDirections,
  source = 'order',
  bumpOrderCount = false,
}) {
  const ref = phoneCustomerRef(db, tenDigits);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const existing = await ref.get();
  const prev = existing.exists ? existing.data() : {};

  const nextName = (name && String(name).trim()) || prev.name || '';
  const nextCompany =
    (company && String(company).trim()) || prev.company || '';
  const nextAddress =
    (address && String(address).trim()) || prev.address || '';
  const nextDirections =
    deliveryDirections != null && String(deliveryDirections).trim()
      ? String(deliveryDirections).trim()
      : prev.delivery_directions || '';

  const patch = {
    phone_digits: tenDigits,
    phone_display: formatDisplayPhone(tenDigits),
    name: nextName,
    company: nextCompany,
    address: nextAddress,
    delivery_directions: nextDirections,
    updated_at: now,
    source: prev.source || source,
  };
  if (!existing.exists) {
    patch.created_at = now;
    patch.order_count = bumpOrderCount ? 1 : 0;
  } else if (bumpOrderCount) {
    patch.order_count = admin.firestore.FieldValue.increment(1);
    patch.last_ordered_at = now;
  }
  if (bumpOrderCount && !existing.exists) {
    patch.last_ordered_at = now;
  }

  await ref.set(patch, { merge: true });
  return getPhoneCustomer(db, tenDigits);
}

async function findAppUserByPhone(db, tenDigits) {
  const variants = [
    tenDigits,
    `0${tenDigits}`,
    `+90${tenDigits}`,
    `90${tenDigits}`,
    formatDisplayPhone(tenDigits),
  ];
  // OTP kullanıcıları çoğunlukla users/{customer_0XXXXXXXXXX} — phone alanı boş kalmış olabilir.
  const docIds = [
    `customer_${tenDigits}`,
    `customer_0${tenDigits}`,
    `customer_+90${tenDigits}`,
    `customer_90${tenDigits}`,
    tenDigits,
    `0${tenDigits}`,
  ];
  for (const id of docIds) {
    const snap = await db.collection('users').doc(id).get();
    if (snap.exists) {
      const data = snap.data() || {};
      if (!data.role || data.role === 'customer') {
        return { id: snap.id, ...data };
      }
    }
  }
  for (const phone of variants) {
    const snap = await db
      .collection('users')
      .where('phone', '==', phone)
      .limit(1)
      .get();
    if (!snap.empty) {
      const doc = snap.docs[0];
      return { id: doc.id, ...doc.data() };
    }
  }
  return null;
}

async function findCustomerByPhone(db, tenDigits) {
  // Uygulama hesabı varsa customer_id olarak onu kullan (Siparişlerim eşleşsin).
  const appUser = await findAppUserByPhone(db, tenDigits);
  const book = await getPhoneCustomer(db, tenDigits);

  if (book && (book.address || book.name || book.company)) {
    return {
      id: appUser?.id || `phone_${tenDigits}`,
      name: book.name || appUser?.name || book.company || null,
      company: book.company || null,
      phone: book.phone_display || formatDisplayPhone(tenDigits),
      last_address: book.address || null,
      last_directions: book.delivery_directions || null,
      from_phonebook: true,
      app_user_linked: Boolean(appUser),
    };
  }

  if (appUser) {
    return {
      id: appUser.id,
      name: appUser.name || null,
      company: appUser.company || null,
      phone: appUser.phone || formatDisplayPhone(tenDigits),
      last_address:
        appUser.default_address || appUser.address || null,
      last_directions: appUser.delivery_directions || null,
      from_phonebook: false,
      app_user_linked: true,
    };
  }

  const ordersSnap = await db
    .collection('orders')
    .where('customer_phone', '==', formatDisplayPhone(tenDigits))
    .orderBy('created_at', 'desc')
    .limit(1)
    .get()
    .catch(() => null);
  if (ordersSnap && !ordersSnap.empty) {
    const o = ordersSnap.docs[0].data();
    return {
      id: o.customer_id || `phone_${tenDigits}`,
      name: o.customer_name,
      phone: o.customer_phone,
      last_address: o.address,
      last_directions: o.delivery_directions || null,
      from_phonebook: false,
      app_user_linked: false,
    };
  }
  return null;
}

async function loadStoreStatus(db) {
  const snap = await db.collection('meta').doc(TRAINING_DOC).get();
  const data = snap.exists ? snap.data() || {} : {};
  const hours = normalizeBusinessHours(
    data.business_hours || data.businessHours,
  );
  return evaluateStoreOpen(hours);
}

function speakHint(user) {
  if (!user) return null;
  const name = user.name || user.customer_name || null;
  const hasAddress = Boolean(user.last_address);
  const bits = [];
  // Kayıtlı müşteriye ASLA isim sorma (kaç kez söylendi: sadece aynı adres).
  if (hasAddress) {
    bits.push(
      (name ? `KAYITLI MÜŞTERİ. ad="${name}" (sessiz bil). ` : 'KAYITLI MÜŞTERİ. ') +
        'İSİM SORMA — YASAK. ' +
        'ÖNCE tek soru: "Aynı adrese mi göndereyim?" ' +
        'Evet → useSavedAddress=true. Hayır/farklı → yalnız yeni adresi al; useSavedAddress=false + address. ' +
        'Sonra ürün/içecek. Bitince TEK create_phone_order. ' +
        'Çay paket yok. Açık ayran yok (ayran → w_ayran).',
    );
  } else if (name) {
    bits.push(
      `KAYITLI İSİM ("${name}") — İSİM SORMA. Adres yok; ürünlerden sonra yalnız "Adresi alabilir miyim?" ` +
        'Bitince TEK create_phone_order. Çay/açık ayran paket yok.',
    );
  } else {
    bits.push(
      'Kayıtlı adres/isim yok. Ürünlerden sonra adres + isim sor. Bitince TEK create_phone_order. ' +
        'Çay/açık ayran paket yok.',
    );
  }
  bits.push(
    'Görüşme boyunca ara kayıt YOK. Tek üründe özellikler netse "hangisi?" SORMA. ' +
      'İngilizce yok. İç not okuma. Kayıt yoksa "aynı adrese" ASLA deme.',
  );
  return bits.join(' ');
}

/**
 * Açık telefon siparişi (görüşme sırasında). phone_customers.open_order_id ile bağlanır.
 */
async function upsertLivePhoneOrder(db, {
  tenDigits,
  known,
  body = {},
  finalize = false,
  seedOnly = false,
  preferredOrderId = null,
}) {
  const bookRef = phoneCustomerRef(db, tenDigits);
  const bookSnap = await bookRef.get();
  const bookData = bookSnap.exists ? bookSnap.data() || {} : {};
  let orderId =
    preferredOrderId ||
    bookData.open_order_id ||
    null;
  let existing = null;
  if (orderId) {
    const snap = await db.collection('orders').doc(orderId).get();
    if (snap.exists) {
      existing = snap.data();
      // Tamamlanmış siparişe yazma — yeni görüşme için yeni sipariş aç
      if (existing.phone_incomplete === false) {
        orderId = null;
        existing = null;
      }
    } else {
      orderId = null;
    }
  }

  let orderNumber;
  let createdAt;
  const now = admin.firestore.Timestamp.now();
  if (!orderId) {
    orderNumber = await nextOrderNumber(db);
    orderId = `order_${orderNumber}`;
    createdAt = now;
  } else {
    orderNumber = Number(existing.order_number) || (await nextOrderNumber(db));
    // İlk oluşturulma anını koru (Türkiye saati doğru kalsın)
    createdAt = existing.created_at || now;
  }

  let address = String(body.address || '').trim();
  const useSavedAddress =
    body.useSavedAddress === true ||
    body.use_saved_address === true ||
    seedOnly ||
    Boolean(known?.last_address);
  if (!address && known?.last_address) {
    address = String(known.last_address).trim();
  }
  if (!address && existing?.address) {
    address = String(existing.address).trim();
  }
  if (!address) {
    address = finalize
      ? 'Adres alınamadı (telefon)'
      : 'Adres görüşmede…';
  }

  const hasItemsPayload = Array.isArray(body.items);
  let items;
  if (hasItemsPayload) {
    items = mapItems(body.items, { allowEmpty: true });
  } else if (existing?.items) {
    items = existing.items;
  } else {
    items = [];
  }

  const totalFromItems = items.reduce(
    (sum, it) => sum + Number(it.unit_price) * Number(it.quantity),
    0,
  );
  const totalAmount = Number(
    body.totalAmount ?? body.total_amount ?? totalFromItems,
  );
  const branchId = String(
    body.branchId || body.branch_id || existing?.branch_id || 'branch_1',
  ).trim();

  const customerName = String(
    body.customerName ||
      body.customer_name ||
      known?.name ||
      known?.company ||
      existing?.customer_name ||
      'Telefon müşteri',
  ).trim();
  const company = String(
    body.company || body.firma || known?.company || '',
  ).trim();
  const displayName = company
    ? `${customerName}${customerName ? ' / ' : ''}${company}`.replace(/^ \/ /, '')
    : customerName;

  const paymentMethod = paymentMethodFromBody(
    body.paymentMethod || body.payment_method || existing?.payment_method,
  );
  let deliveryDirections =
    body.deliveryDirections ||
    body.delivery_directions ||
    existing?.delivery_directions ||
    null;
  if (!deliveryDirections && known?.last_directions) {
    deliveryDirections = known.last_directions;
  }
  const orderNote =
    body.orderNote || body.order_note || existing?.order_note || null;

  const incomplete = finalize ? false : true;
  // Siparişlerim: OTP kullanıcı id'si customer_0XXXXXXXXXX — mümkünse app user, yoksa aynı format.
  const customerId =
    known?.id ||
    existing?.customer_id ||
    `customer_0${tenDigits}`;

  const doc = {
    id: orderId,
    order_number: orderNumber,
    customer_id: customerId,
    customer_name: displayName,
    branch_id: branchId,
    items,
    total_amount: totalAmount,
    status: existing?.status || 'received',
    created_at: createdAt,
    updated_at: now,
    address,
    payment_method: paymentMethod,
    customer_phone: formatDisplayPhone(tenDigits),
    customer_phone_digits: tenDigits,
    delivery_now: true,
    order_type: 'delivery',
    is_pickup: false,
    is_table_addon: false,
    order_source: 'phone',
    phone_incomplete: incomplete,
    discount_amount: Number(existing?.discount_amount || 0) || 0,
    delivery_fee_amount: Number(
      body.deliveryFeeAmount ?? existing?.delivery_fee_amount ?? 0,
    ) || 0,
    status_timestamps: existing?.status_timestamps || { received: createdAt },
    approach_notification_sent:
      existing?.approach_notification_sent === true,
    preparation_tags: Array.isArray(body.preparationTags)
      ? body.preparationTags
      : existing?.preparation_tags || [],
  };
  if (orderNote) doc.order_note = String(orderNote);
  if (deliveryDirections) {
    doc.delivery_directions = String(deliveryDirections);
  }
  if (!incomplete) {
    doc.phone_completed_at = now;
  }

  await db.collection('orders').doc(orderId).set(doc, { merge: true });

  const bookPatch = {
    phone_digits: tenDigits,
    phone_display: formatDisplayPhone(tenDigits),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (customerName && customerName !== 'Telefon müşteri') {
    bookPatch.name = customerName;
  }
  if (company) bookPatch.company = company;
  if (address && !address.startsWith('Adres')) {
    bookPatch.address = address;
    bookPatch.last_address = address;
  }
  if (deliveryDirections) {
    bookPatch.delivery_directions = String(deliveryDirections);
  }
  if (incomplete) {
    bookPatch.open_order_id = orderId;
  } else {
    bookPatch.open_order_id = admin.firestore.FieldValue.delete();
    bookPatch.last_ordered_at = admin.firestore.FieldValue.serverTimestamp();
    bookPatch.order_count = admin.firestore.FieldValue.increment(1);
  }
  await bookRef.set(bookPatch, { merge: true });

  console.log('upsertLivePhoneOrder', {
    orderId,
    orderNumber,
    tenDigits,
    items: items.length,
    incomplete,
    seedOnly,
    finalize,
  });

  return {
    orderId,
    orderNumber,
    items,
    address,
    customerName: displayName,
    phoneIncomplete: incomplete,
    totalAmount,
  };
}

/**
 * ElevenLabs conversation-initiation webhook.
 * Sadece arayan bilgisi / dyn vars — canlı taslak sipariş AÇMAZ (sistemi kasıyor).
 */
async function handlePhoneCallInit(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST' && req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    assertSecret(req);
    const body = {
      ...((req.method === 'GET' ? req.query : readJsonBody(req)) || {}),
      ...(req.query || {}),
    };
    console.log('phoneCallInit_in', {
      keys: Object.keys(body || {}),
      caller: String(
        body.caller_id || body.callerId || body.phone || '',
      ).slice(0, 40),
      agent: body.agent_id || body.agentId || null,
    });

    const ten = normalizeTrPhone(
      body.caller_id ||
        body.callerId ||
        body.phone ||
        body.customerPhone ||
        body.system__caller_id ||
        body.from,
    );

    if (!ten) {
      console.warn('phoneCallInit_no_phone', { keys: Object.keys(body || {}) });
      res.status(200).json({
        type: 'conversation_initiation_client_data',
        dynamic_variables: {
          known_caller_phone: '',
          customer_name: '',
          store_open: 'unknown',
        },
      });
      return;
    }

    const db = admin.firestore();
    const store = await loadStoreStatus(db);
    const user = await findCustomerByPhone(db, ten);
    const customerName = user?.name || user?.customer_name || null;
    const displayPhone = formatDisplayPhone(ten);

    const dyn = {
      known_caller_phone: displayPhone,
      customer_name: customerName || user?.company || '',
      store_open: store.open ? 'true' : 'false',
    };

    const payload = {
      type: 'conversation_initiation_client_data',
      dynamic_variables: dyn,
    };

    if (!store.open) {
      payload.conversation_config_override = {
        agent: {
          first_message: String(store.closedMessage || 'Şu an kapalıyız.').trim(),
        },
      };
    }

    console.log('phoneCallInit_ok', {
      ten,
      storeOpen: store.open,
      known: Boolean(user),
    });
    res.status(200).json(payload);
  } catch (e) {
    const code = e.code || 'init_failed';
    console.error('phoneCallInit', code, e.message);
    if (code === 'unauthorized') {
      res.status(401).json({ error: code });
      return;
    }
    res.status(200).json({
      type: 'conversation_initiation_client_data',
      dynamic_variables: {
        known_caller_phone: '',
        customer_name: '',
        store_open: 'unknown',
      },
    });
  }
}

async function handleLookupPhoneCustomer(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST' && req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    assertSecret(req);
    const body = req.method === 'GET' ? req.query : readJsonBody(req);
    const ten = normalizeTrPhone(
      body.phone ||
        body.customerPhone ||
        body.caller_id ||
        body.system__caller_id,
    );
    if (!ten) {
      res.status(400).json({ error: 'invalid_phone' });
      return;
    }
    const db = admin.firestore();
    const store = await loadStoreStatus(db);
    if (!store.open) {
      res.status(200).json({
        found: false,
        phone: formatDisplayPhone(ten),
        storeOpen: false,
        closedMessage: store.closedMessage,
        todayHours: store.todayHours,
        todayLabel: store.todayLabel,
        nowTr: store.nowTr,
        askAddress: false,
        askName: false,
        agentHint:
          `KAPALI (${store.todayLabel}${store.todayHours ? ` ${store.todayHours}` : ''}). ` +
          `Müşteriye aynen söyle: "${store.closedMessage}" ` +
          'Sipariş alma. create_phone_order çağırma. Sonra end_call.',
      });
      return;
    }

    const user = await findCustomerByPhone(db, ten);
    const address =
      user?.last_address || user?.default_address || user?.address || null;
    const customerName = user?.name || user?.customer_name || null;
    const skipAskAddress = Boolean(address);
    const skipAskName = Boolean(customerName || user?.company);

    if (!user) {
      res.status(200).json({
        found: false,
        phone: formatDisplayPhone(ten),
        storeOpen: true,
        todayHours: store.todayHours,
        todayLabel: store.todayLabel,
        askAddress: true,
        askName: true,
        skipAskAddress: false,
        skipAskName: false,
        agentHint:
          'KAYIT YOK (found=false). "Aynı adrese" YASAK. ' +
          'Ürün+içecek+"başka bir şey?" bitince HEMEN (bekleme/ara cümle yok): "Adınızı alabilir miyim?" ' +
          'Cevap gelir gelmez: "Teslimat adresinizi alabilir miyim?" ' +
          'create_phone_order: useSavedAddress=false, customerName+address+tüm items. ' +
          'Alındı: "Siparişiniz alındı. İyi günler." Ara kayıt YOK.',
      });
      return;
    }

    // Kayıt var ama adres yok
    if (!skipAskAddress) {
      res.status(200).json({
        found: true,
        phone: formatDisplayPhone(ten),
        customerId: user.id,
        customerName,
        company: user.company || null,
        address: null,
        deliveryDirections:
          user.last_directions || user.delivery_directions || null,
        storeOpen: true,
        todayHours: store.todayHours,
        todayLabel: store.todayLabel,
        askAddress: true,
        askName: false,
        skipAskAddress: false,
        skipAskName: true,
        confirmAddress: false,
        agentHint:
          'KAYITLI — İSİM SORMA. Adres yok. "Aynı adrese" YASAK. ' +
          'Ürünlerden sonra yalnız teslimat adresini sor. ' +
          'create_phone_order: useSavedAddress=false + address. Çay/açık ayran paket yok.',
      });
      return;
    }

    res.status(200).json({
      found: true,
      phone: formatDisplayPhone(ten),
      customerId: user.id,
      customerName,
      company: user.company || null,
      address,
      deliveryDirections:
        user.last_directions || user.delivery_directions || null,
      storeOpen: true,
      todayHours: store.todayHours,
      todayLabel: store.todayLabel,
      askAddress: true,
      askName: false,
      skipAskAddress: false,
      skipAskName: true,
      confirmAddress: true,
      agentHint: speakHint({
        ...user,
        name: customerName,
        last_address: address,
      }),
    });
  } catch (e) {
    const code = e.code || 'lookup_failed';
    const status = code === 'unauthorized' ? 401 : 500;
    console.error('lookupPhoneCustomer', code, e.message);
    res.status(status).json({ error: code });
  }
}

async function handleCreatePhoneOrder(req, res) {
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
    assertSecret(req);
    const body = readJsonBody(req);
    const itemsCheck = Array.isArray(body.items) ? body.items : [];
    // Ara kayıt kapalı: items varsa sipariş tamamlanmış sayılır.
    // (ElevenLabs constant_value finalize bazen false geliyor.)
    const finalizeExplicit =
      body.finalize === true ||
      body.done === true ||
      body.complete === true ||
      String(body.finalize || '').toLowerCase() === 'true';
    const finalize = finalizeExplicit || itemsCheck.length > 0;

    console.log('createPhoneOrder_in', {
      keys: Object.keys(body || {}),
      hasItems: itemsCheck.length,
      finalize,
      finalizeExplicit,
      conversationId:
        body.conversationId ||
        body.conversation_id ||
        body.system__conversation_id ||
        null,
      phoneRaw: String(
        body.customerPhone ||
          body.phone ||
          body.system__caller_id ||
          body.caller_id ||
          '',
      ).slice(0, 24),
      orderId: body.orderId || body.order_id || null,
    });

    if (!finalize || itemsCheck.length === 0) {
      res.status(400).json({
        ok: false,
        error: 'items_required',
        agentHint:
          'items zorunlu. Tüm ürünleri tek seferde gönder; sonra alındı de.',
      });
      return;
    }

    const db = admin.firestore();
    const preferredOrderId = String(
      body.orderId || body.order_id || '',
    ).trim() || null;

    let ten = normalizeTrPhone(
      body.customerPhone ||
        body.phone ||
        body.caller_id ||
        body.callerId ||
        body.system__caller_id ||
        body.known_caller_phone,
    );

    // Telefon boşsa: mevcut sipariş / açık defter kaydından çöz.
    if (!ten && preferredOrderId) {
      const existingSnap = await db.collection('orders').doc(preferredOrderId).get();
      if (existingSnap.exists) {
        const d = existingSnap.data() || {};
        ten = normalizeTrPhone(
          d.customer_phone_digits || d.customer_phone || '',
        );
      }
    }
    if (!ten) {
      // Son çare: defterde open_order ile eşleşen yok; conversation metadata yok.
      // Agent bazen sadece items gönderir — logla ve red et.
      console.warn('createPhoneOrder_invalid_phone', {
        phone: body.customerPhone || body.phone,
        systemCaller: body.system__caller_id,
        preferredOrderId,
      });
      res.status(400).json({
        ok: false,
        error: 'invalid_phone',
        agentHint:
          'Telefon yok. lookup_phone_customer çağırıp create_phone_order’ı tekrar dene.',
      });
      return;
    }

    const store = await loadStoreStatus(db);
    if (!store.open) {
      res.status(403).json({
        ok: false,
        error: 'store_closed',
        closedMessage: store.closedMessage,
        todayHours: store.todayHours,
        agentHint: 'Mağaza kapalı. Sipariş alma; kapalı mesajını söyle ve end_call.',
      });
      return;
    }

    const known = await findCustomerByPhone(db, ten);
    const conversationId = String(
      body.conversationId ||
        body.conversation_id ||
        body.system__conversation_id ||
        '',
    ).trim();

    const savedAddr = String(
      known?.last_address || known?.default_address || known?.address || '',
    ).trim();
    const bodyAddr = String(body.address || '').trim();
    const wantSaved =
      body.useSavedAddress === true || body.use_saved_address === true;
    const resolvedAddr = (wantSaved && savedAddr ? savedAddr : bodyAddr) || savedAddr;
    const addrMissing =
      !resolvedAddr ||
      /^Adres/i.test(resolvedAddr) ||
      /görüşmede|alınamadı/i.test(resolvedAddr);
    if (addrMissing) {
      res.status(400).json({
        ok: false,
        error: 'address_required',
        agentHint:
          'Teslimat adresi yok. "Aynı adrese" DEME. Adresi sor; ' +
          'create_phone_order’ı useSavedAddress=false ve address ile tekrar çağır.',
      });
      return;
    }

    const knownName = String(known?.name || known?.customer_name || known?.company || '').trim();
    const bodyName = String(body.customerName || body.customer_name || '').trim();
    if (!knownName && (!bodyName || bodyName === 'Telefon müşteri')) {
      res.status(400).json({
        ok: false,
        error: 'name_required',
        agentHint:
          'İsim yok. Müşteriye adını sor; create_phone_order’ı customerName ile tekrar çağır.',
      });
      return;
    }

    const blocked = findBlockedPhoneDeliveryItems(
      mapItems(itemsCheck, { allowEmpty: false }),
    );
    if (blocked.length) {
      res.status(400).json({
        ok: false,
        error: 'item_not_for_delivery',
        blocked,
        agentHint:
          'Çay paket olarak gönderilmez. Siparişten çayı çıkar; alternatif içecek öner. ' +
          'Açık ayran paket gitmez — ayran için w_ayran (kapalı) kullan. create_phone_order’ı düzeltip tekrar çağır.',
      });
      return;
    }

    // Açık ayranı kapalıya çevir (mapItems içinde de yapılır)
    body.items = itemsCheck.map((it) => {
      const id = String(it.productId || it.product_id || '').trim();
      const name = String(
        it.productName || it.product_name_key || it.name || '',
      ).trim();
      if (
        id === 'w_acik_ayran' ||
        /açık\s*ayran|acik\s*ayran/i.test(name)
      ) {
        return {
          ...it,
          productId: 'w_ayran',
          product_id: 'w_ayran',
          productName: 'AYRAN',
          product_name_key: 'AYRAN',
        };
      }
      return it;
    });

    const result = await upsertLivePhoneOrder(db, {
      tenDigits: ten,
      known,
      preferredOrderId,
      body: {
        ...body,
        address: resolvedAddr,
        customerName: bodyName || knownName,
        useSavedAddress: wantSaved && Boolean(savedAddr),
      },
      finalize: true,
      seedOnly: false,
    });

    // Başarı işareti — conversationId yoksa da telefona göre kısa ömürlü işaret bırak.
    const successPayload = {
      order_id: result.orderId,
      phone_digits: ten,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (conversationId) {
      await db
        .collection(SUCCESS_COLLECTION)
        .doc(conversationId)
        .set(
          {
            ...successPayload,
            conversation_id: conversationId,
          },
          { merge: true },
        );
      await db
        .collection('orders')
        .doc(result.orderId)
        .set(
          {
            phone_conversation_id: conversationId,
            phone_failed: false,
            phone_incomplete: false,
          },
          { merge: true },
        );
      await db
        .collection(FAILED_COLLECTION)
        .doc(conversationId)
        .set(
          {
            status: 'converted',
            order_id: result.orderId,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        )
        .catch(() => null);
      await clearFailedPhoneOrderMirror(db, conversationId);
    } else {
      await db
        .collection('orders')
        .doc(result.orderId)
        .set(
          {
            phone_failed: false,
            phone_incomplete: false,
          },
          { merge: true },
        );
      // conversationId gelmezse son başarılı siparişi telefona yaz (failed sync eşleşsin)
      await db
        .collection(SUCCESS_COLLECTION)
        .doc(`phone_${ten}`)
        .set(
          {
            ...successPayload,
            conversation_id: null,
            by_phone: true,
          },
          { merge: true },
        )
        .catch(() => null);
    }

    res.status(200).json({
      ok: true,
      orderId: result.orderId,
      orderNumber: result.orderNumber,
      status: 'received',
      orderSource: 'phone',
      totalAmount: result.totalAmount,
      savedAddress: result.address,
      phoneIncomplete: false,
      itemCount: result.items.length,
      agentHint: 'Sipariş TAMAMLANDI. Müşteriye alındı de ve end_call.',
    });
  } catch (e) {
    const code = e.code || 'create_failed';
    const status =
      code === 'unauthorized'
        ? 401
        : code === 'items_required' || code === 'invalid_item'
          ? 400
          : 500;
    console.error('createPhoneOrder', code, e.message);
    res.status(status).json({ ok: false, error: code });
  }
}

function mapImportRow(row) {
  const phone = normalizeTrPhone(
    row.phone || row.telefon || row.Telefon || row.PHONE || row.numara,
  );
  if (!phone) return null;
  return {
    tenDigits: phone,
    name: String(
      row.name || row.isim || row.ad || row.Ad || row.Name || '',
    ).trim(),
    company: String(
      row.company ||
        row.firma ||
        row.Firma ||
        row.sirket ||
        row.Company ||
        '',
    ).trim(),
    address: String(
      row.address || row.adres || row.Adres || row.Address || '',
    ).trim(),
    deliveryDirections: String(
      row.directions ||
        row.tarif ||
        row.yol_tarifi ||
        row.note ||
        row.not ||
        '',
    ).trim(),
  };
}

async function handleImportPhoneCustomers(req, res) {
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
    assertSecret(req);
    const body = readJsonBody(req);
    const rows = Array.isArray(body.rows)
      ? body.rows
      : Array.isArray(body.customers)
        ? body.customers
        : [];
    if (rows.length === 0) {
      res.status(400).json({ error: 'rows_required' });
      return;
    }
    const db = admin.firestore();
    let imported = 0;
    let skipped = 0;
    for (const row of rows) {
      const mapped = mapImportRow(row);
      if (!mapped || (!mapped.address && !mapped.name && !mapped.company)) {
        skipped += 1;
        continue;
      }
      await upsertPhoneCustomer(db, {
        ...mapped,
        source: 'excel',
        bumpOrderCount: false,
      });
      imported += 1;
    }
    res.status(200).json({ ok: true, imported, skipped, total: rows.length });
  } catch (e) {
    const code = e.code || 'import_failed';
    const status = code === 'unauthorized' ? 401 : 500;
    console.error('importPhoneCustomers', code, e.message);
    res.status(status).json({ error: code });
  }
}

async function handleListPhoneCustomers(req, res) {
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
    assertSecret(req);
    const db = admin.firestore();
    const snap = await db
      .collection(COLLECTION)
      .orderBy('updated_at', 'desc')
      .limit(500)
      .get()
      .catch(async () => db.collection(COLLECTION).limit(500).get());
    const customers = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    res.status(200).json({ customers });
  } catch (e) {
    console.error('listPhoneCustomers', e.message);
    res.status(500).json({ error: 'list_failed' });
  }
}

async function handleUpdatePhoneCustomer(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST' && req.method !== 'PUT' && req.method !== 'PATCH') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    assertSecret(req);
    const body = readJsonBody(req);
    const db = admin.firestore();
    const originalTen = normalizeTrPhone(
      body.id || body.phone_digits || body.originalPhone || body.original_phone,
    );
    const nextTen = normalizeTrPhone(
      body.phone || body.telefon || body.phone_display || body.customerPhone,
    );
    if (!nextTen) {
      res.status(400).json({ error: 'invalid_phone' });
      return;
    }
    const name = String(body.name || body.isim || '').trim();
    const company = String(body.company || body.firma || '').trim();
    const address = String(body.address || body.adres || '').trim();
    const deliveryDirections = String(
      body.deliveryDirections ||
        body.delivery_directions ||
        body.tarif ||
        body.directions ||
        '',
    ).trim();

    const saved = await upsertPhoneCustomer(db, {
      tenDigits: nextTen,
      name,
      company,
      address,
      deliveryDirections,
      source: 'admin',
      bumpOrderCount: false,
    });

    // Numara değiştiyse eski kaydı sil
    if (originalTen && originalTen !== nextTen) {
      await phoneCustomerRef(db, originalTen).delete().catch(() => null);
    }

    res.status(200).json({ ok: true, customer: saved });
  } catch (e) {
    const code = e.code || 'update_failed';
    const status = code === 'unauthorized' ? 401 : 500;
    console.error('updatePhoneCustomer', code, e.message);
    res.status(status).json({ error: code });
  }
}

async function handleDeletePhoneCustomer(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST' && req.method !== 'DELETE') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    assertSecret(req);
    const body =
      req.method === 'DELETE' && (!req.body || Object.keys(req.body).length === 0)
        ? req.query
        : readJsonBody(req);
    const ten = normalizeTrPhone(
      body.id || body.phone || body.telefon || body.phone_digits || body.customerPhone,
    );
    if (!ten) {
      res.status(400).json({ error: 'invalid_phone' });
      return;
    }
    const db = admin.firestore();
    await phoneCustomerRef(db, ten).delete();
    res.status(200).json({ ok: true, deleted: ten });
  } catch (e) {
    const code = e.code || 'delete_failed';
    const status = code === 'unauthorized' ? 401 : 500;
    console.error('deletePhoneCustomer', code, e.message);
    res.status(status).json({ error: code });
  }
}

function elevenLabsHttpsJson(method, pathName, apiKey, bodyObj) {
  const https = require('https');
  const data = bodyObj ? JSON.stringify(bodyObj) : null;
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: 'api.elevenlabs.io',
        path: pathName,
        method,
        headers: {
          'xi-api-key': apiKey,
          Accept: 'application/json',
          ...(data
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(data),
              }
            : {}),
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => {
          raw += c;
        });
        res.on('end', () => {
          let json = null;
          try {
            json = raw ? JSON.parse(raw) : null;
          } catch (_) {
            json = { raw };
          }
          resolve({ status: res.statusCode, json });
        });
      },
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function transcriptNotesFromConversation(detail) {
  const analysis = detail.analysis || {};
  const summary = String(analysis.transcript_summary || '').trim();
  const title = String(analysis.call_summary_title || '').trim();
  const lines = [];
  if (title) lines.push(title);
  if (summary) lines.push(summary);
  const userLines = [];
  for (const turn of detail.transcript || []) {
    if (turn.role !== 'user') continue;
    const msg = String(turn.message || '').trim();
    if (!msg) continue;
    userLines.push(msg);
    if (userLines.length >= 12) break;
  }
  if (userLines.length) {
    lines.push('Müşteri: ' + userLines.join(' | '));
  }
  return lines.join('\n').slice(0, 4000);
}

function phoneFromConversationDetail(detail) {
  const meta = detail.metadata || {};
  const phoneCall = meta.phone_call || {};
  const dyn =
    (detail.conversation_initiation_client_data &&
      detail.conversation_initiation_client_data.dynamic_variables) ||
    {};
  return normalizeTrPhone(
    phoneCall.external_number ||
      dyn.system__caller_id ||
      dyn.known_caller_phone ||
      dyn.phone,
  );
}

function conversationHadCreateTool(detail) {
  for (const turn of detail.transcript || []) {
    for (const tc of turn.tool_calls || []) {
      const name = String(tc.tool_name || tc.name || '').toLowerCase();
      if (name.includes('create_phone')) return true;
    }
    if (String(turn.tool_name || '').toLowerCase().includes('create_phone')) {
      return true;
    }
  }
  return false;
}

function conversationHadEndCall(detail) {
  for (const turn of detail.transcript || []) {
    for (const tc of turn.tool_calls || []) {
      const name = String(tc.tool_name || tc.name || '').toLowerCase();
      if (name.includes('end_call')) return true;
    }
    if (String(turn.tool_name || '').toLowerCase().includes('end_call')) {
      return true;
    }
  }
  return false;
}

/** Ajan gerçekten “alındı” dedi mi? (analysis.success tek başına yetmez) */
function agentSaidOrderConfirmed(detail) {
  for (const turn of detail.transcript || []) {
    if (turn.role !== 'agent') continue;
    const msg = String(turn.message || '');
    if (/siparişiniz alındı|siparişinizi aldım|aynı adrese gönderiyoruz/i.test(msg)) {
      return true;
    }
  }
  return false;
}

function agentClaimedOrderTaken(detail) {
  const analysis = detail.analysis || {};
  if (String(analysis.call_successful || '').toLowerCase() === 'success') {
    return true;
  }
  return agentSaidOrderConfirmed(detail);
}

/** Görüşme düzgün tamamlanmadan koptu / yarıda kaldı mı? */
function isAbruptOrIncompletePhoneCall(detail) {
  const meta = detail.metadata || {};
  const reason = String(meta.termination_reason || '').toLowerCase();
  const analysis = detail.analysis || {};
  const callSuccessful = String(analysis.call_successful || '').toLowerCase();

  if (
    callSuccessful === 'failure' ||
    callSuccessful === 'failed' ||
    callSuccessful === 'unsuccessful'
  ) {
    return true;
  }

  // Gerçek başarı: create + müşteriye “alındı” cümlesi
  const properlyCompleted =
    conversationHadCreateTool(detail) && agentSaidOrderConfirmed(detail);
  if (properlyCompleted && callSuccessful === 'success') {
    return false;
  }
  if (properlyCompleted) {
    // Alındı denmiş; müşteri kapattıysa başarı say
    if (
      /end_call|agent_ended|completed|user_hang|client_hang|remote_hang|customer/i.test(
        reason,
      ) ||
      conversationHadEndCall(detail) ||
      !reason
    ) {
      return false;
    }
  }

  // Create var ama “alındı” yok → erken kayıt / yarıda kesilme
  if (conversationHadCreateTool(detail) && !agentSaidOrderConfirmed(detail)) {
    return true;
  }

  if (
    /timeout|silence|error|network|disconnect|drop|abort|crash|failed|busy|reject|lost/i.test(
      reason,
    )
  ) {
    return true;
  }

  // Create yoksa başarısız görüşme yolu
  if (!conversationHadCreateTool(detail)) {
    return true;
  }

  return !properlyCompleted;
}

const FAILED_CALL_NOTE = 'Başarısız arama — görüşme yarıda kesildi';

/**
 * Erken create_phone_order ile “başarılı” görünen siparişi başarısız uyarısına çevir.
 */
async function demotePrematurePhoneSuccess(db, {
  conversationId,
  orderId,
  tenDigits,
}) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  if (orderId) {
    const ref = db.collection('orders').doc(orderId);
    const snap = await ref.get();
    const prev = snap.exists ? snap.data() || {} : {};
    const stamps = { ...(prev.status_timestamps || {}) };
    stamps.cancelled = now;
    await ref.set(
      {
        phone_failed: true,
        phone_incomplete: false,
        phone_aborted: true,
        order_note: FAILED_CALL_NOTE,
        status: 'cancelled',
        updated_at: now,
        status_timestamps: stamps,
        phone_conversation_id: conversationId || prev.phone_conversation_id || null,
      },
      { merge: true },
    );
  }

  if (conversationId) {
    await db.collection(SUCCESS_COLLECTION).doc(conversationId).delete().catch(() => null);
  }
  if (tenDigits) {
    await db
      .collection(SUCCESS_COLLECTION)
      .doc(`phone_${tenDigits}`)
      .delete()
      .catch(() => null);
  }

  // Boş ayna kayıt gerekmez — asıl sipariş phone_failed oldu.
  if (conversationId) {
    await clearFailedPhoneOrderMirror(db, conversationId);
  }
}

function normalizeMenuText(s) {
  return String(s || '')
    .toLocaleLowerCase('tr-TR')
    .replace(/ı/g, 'i')
    .replace(/İ/g, 'i')
    .replace(/ş/g, 's')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function loadMenuCatalog() {
  try {
    // eslint-disable-next-line global-require, import/no-dynamic-require
    return require('./phone_menu_catalog.json');
  } catch (_) {
    return [];
  }
}

/**
 * Ajan tool çağırmadan “alındı” dediyse transcript/özetten menü kalemlerini çıkar.
 */
function matchItemsFromConversationText(text) {
  const hay = normalizeMenuText(text);
  if (!hay) return [];
  const catalog = loadMenuCatalog();
  if (!catalog.length) return [];

  const scored = [];
  for (const p of catalog) {
    const name = normalizeMenuText(p.name || p.id);
    if (!name || name.length < 4) continue;
    if (!hay.includes(name)) continue;
    scored.push({
      id: p.id,
      name: p.name,
      price: Number(p.price) || 0,
      score: name.length,
    });
  }
  // En uzun eşleşmeler (daha spesifik ürün)
  scored.sort((a, b) => b.score - a.score);
  const picked = [];
  for (const row of scored) {
    const nameNorm = normalizeMenuText(row.name);
    // Daha kısa isim, seçilmiş daha uzun ürünün parçasıysa atla
    if (picked.some((x) => x.nameNorm.includes(nameNorm) && x.nameNorm !== nameNorm)) {
      continue;
    }
    // Yeni uzun isim, daha kısa seçilmişleri ezer
    for (let i = picked.length - 1; i >= 0; i -= 1) {
      if (nameNorm.includes(picked[i].nameNorm) && nameNorm !== picked[i].nameNorm) {
        picked.splice(i, 1);
      }
    }
    picked.push({ ...row, nameNorm });
    if (picked.length >= 8) break;
  }

  return picked.map((p, index) => ({
    id: `phone_recover_${index + 1}`,
    product_id: p.id,
    product_name_key: p.name,
    unit_price: p.price,
    quantity: 1,
    selected_options: [],
  }));
}

async function recoverPhoneOrderFromConversation(db, detail, tenDigits) {
  if (!tenDigits) return null;
  if (conversationHadCreateTool(detail)) return null;
  if (!agentClaimedOrderTaken(detail)) return null;

  const analysis = detail.analysis || {};
  const bits = [String(analysis.transcript_summary || '')];
  for (const turn of detail.transcript || []) {
    if (turn.role === 'user' || turn.role === 'agent') {
      bits.push(String(turn.message || ''));
    }
  }
  const items = matchItemsFromConversationText(bits.join('\n'));
  if (!items.length) {
    console.warn('recoverPhoneOrder_no_items', {
      conversationId: detail.conversation_id,
      tenDigits,
    });
    return null;
  }

  const known = await findCustomerByPhone(db, tenDigits);
  const conversationId = String(detail.conversation_id || '').trim();
  const result = await upsertLivePhoneOrder(db, {
    tenDigits,
    known,
    preferredOrderId: null,
    body: {
      items: items.map((it) => ({
        productId: it.product_id,
        productName: it.product_name_key,
        unitPrice: it.unit_price,
        quantity: it.quantity,
      })),
      useSavedAddress: Boolean(known?.last_address),
      orderNote: null,
      conversationId,
    },
    finalize: true,
    seedOnly: false,
  });

  await db
    .collection('orders')
    .doc(result.orderId)
    .set(
      {
        phone_failed: false,
        phone_incomplete: false,
        phone_recovered: true,
        // Müşteri/fiş açıklamasına kurtarma metni yazma.
        order_note: admin.firestore.FieldValue.delete(),
        phone_conversation_id: conversationId || null,
      },
      { merge: true },
    );

  if (conversationId) {
    await db
      .collection(SUCCESS_COLLECTION)
      .doc(conversationId)
      .set(
        {
          conversation_id: conversationId,
          order_id: result.orderId,
          phone_digits: tenDigits,
          recovered: true,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    await clearFailedPhoneOrderMirror(db, conversationId);
    await db
      .collection(FAILED_COLLECTION)
      .doc(conversationId)
      .set(
        {
          status: 'converted',
          order_id: result.orderId,
          recovered: true,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      )
      .catch(() => null);
  } else {
    await db
      .collection(SUCCESS_COLLECTION)
      .doc(`phone_${tenDigits}`)
      .set(
        {
          order_id: result.orderId,
          phone_digits: tenDigits,
          recovered: true,
          by_phone: true,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      )
      .catch(() => null);
  }

  console.log('recoverPhoneOrder_ok', {
    orderId: result.orderId,
    items: items.length,
    tenDigits,
    conversationId,
  });
  return result;
}

async function closeStaleLiveDrafts(db) {
  const snap = await db
    .collection('orders')
    .where('order_source', '==', 'phone')
    .where('phone_incomplete', '==', true)
    .limit(40)
    .get()
    .catch(() => null);
  if (!snap || snap.empty) return 0;
  let n = 0;
  const batch = db.batch();
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const items = Array.isArray(data.items) ? data.items : [];
    batch.set(
      doc.ref,
      {
        phone_incomplete: false,
        status: items.length ? data.status || 'cancelled' : 'cancelled',
        order_note: [
          data.order_note,
          'Eski görüşme taslağı kapatıldı (canlı kayıt kaldırıldı).',
        ]
          .filter(Boolean)
          .join(' | ')
          .slice(0, 500),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    n += 1;
  }
  await batch.commit();
  return n;
}

function failedPhoneOrderDocId(conversationId) {
  return `phone_failed_${conversationId}`;
}

async function clearFailedPhoneOrderMirror(db, conversationId) {
  if (!conversationId) return;
  const orderId = failedPhoneOrderDocId(conversationId);
  await db.collection('orders').doc(orderId).delete().catch(() => null);
}

/**
 * Başarısız görüşmeyi ana sipariş listesinde "Başarısız" olarak göstermek için
 * orders koleksiyonuna ayna kayıt yazar. phone_failed_orders ayrı kalır.
 */
async function upsertFailedPhoneOrderMirror(db, {
  conversationId,
  tenDigits,
  customerName,
  address,
  notes,
  createdAt,
}) {
  const orderId = failedPhoneOrderDocId(conversationId);
  const ref = db.collection('orders').doc(orderId);
  const existing = await ref.get();
  let orderNumber;
  let created = createdAt || admin.firestore.Timestamp.now();
  if (existing.exists) {
    orderNumber =
      Number(existing.data()?.order_number) ||
      (await nextOrderNumber(db));
    created = existing.data()?.created_at || created;
  } else {
    orderNumber = await nextOrderNumber(db);
  }

  const known = await findCustomerByPhone(db, tenDigits);
  const name =
    customerName ||
    known?.name ||
    known?.customer_name ||
    known?.company ||
    'Telefon müşteri';
  const addr =
    address ||
    known?.last_address ||
    known?.address ||
    'Adres alınamadı (başarısız görüşme)';
  const noteText = notes || FAILED_CALL_NOTE;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const customerId =
    known?.id || `customer_0${tenDigits}`;

  await ref.set(
    {
      id: orderId,
      order_number: orderNumber,
      customer_id: customerId,
      customer_name: name,
      branch_id: 'branch_1',
      items: [],
      total_amount: 0,
      status: 'cancelled',
      created_at: created,
      updated_at: now,
      address: addr,
      payment_method: 'cashOnDelivery',
      customer_phone: formatDisplayPhone(tenDigits),
      customer_phone_digits: tenDigits,
      delivery_now: true,
      order_type: 'delivery',
      is_pickup: false,
      is_table_addon: false,
      order_source: 'phone',
      phone_incomplete: false,
      phone_failed: true,
      phone_conversation_id: conversationId,
      // Ayrıntı phone_failed_orders'ta; ana listede uzun not gösterme.
      order_note: noteText,
      discount_amount: 0,
      delivery_fee_amount: 0,
      status_timestamps: {
        received: created,
        cancelled: now,
      },
      approach_notification_sent: false,
      preparation_tags: [],
    },
    { merge: true },
  );
  return orderId;
}

async function upsertFailedPhoneOrderFromDetail(db, detail) {
  const conversationId = String(detail.conversation_id || '').trim();
  if (!conversationId) return { skipped: true, reason: 'no_conversation_id' };

  const abrupt = isAbruptOrIncompletePhoneCall(detail);
  const success = await db.collection(SUCCESS_COLLECTION).doc(conversationId).get();
  if (success.exists) {
    const orderId = success.data()?.order_id || null;
    const tenFromSuccess = String(success.data()?.phone_digits || '').trim();
    // Erken create + yarıda kesilme → başarıyı iptal et, uyarı olarak göster
    if (abrupt) {
      const ten =
        phoneFromConversationDetail(detail) || tenFromSuccess || null;
      await demotePrematurePhoneSuccess(db, {
        conversationId,
        orderId,
        tenDigits: ten,
      });
      console.warn('phone_order_demote_abrupt_success', {
        conversationId,
        orderId,
        tenDigits: ten,
      });
      // Aşağıda FAILED_COLLECTION kaydı da yazılsın
    } else {
      await db
        .collection(FAILED_COLLECTION)
        .doc(conversationId)
        .set(
          {
            status: 'converted',
            order_id: orderId,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        )
        .catch(() => null);
      await clearFailedPhoneOrderMirror(db, conversationId);
      return { skipped: true, reason: 'already_success' };
    }
  }

  const meta = detail.metadata || {};
  const duration = Number(meta.call_duration_secs || 0);
  const startUnix = Number(meta.start_time_unix_secs || 0);
  const messageCount = Array.isArray(detail.transcript)
    ? detail.transcript.length
    : 0;
  // Çok kısa / boş aramalar başarısız sipariş sayılmaz
  if (duration < 10 && messageCount < 4) {
    return { skipped: true, reason: 'too_short' };
  }

  const ten = phoneFromConversationDetail(detail);
  if (!ten) return { skipped: true, reason: 'no_phone' };

  // Otomatik kurtarma KAPALI: ajan tool çağırmadıysa mutfak fişi basılmaz.
  // Yalnızca ana listede "Başarısız" + telefon görünür.
  if (agentClaimedOrderTaken(detail) && !conversationHadCreateTool(detail)) {
    console.warn('phone_order_skip_auto_recover', {
      conversationId,
      tenDigits: ten,
      reason: 'agent_claimed_without_create_tool',
    });
  }

  // Telefona göre yakın zamanda başarı işareti (yalnızca görüşme gerçekten tamamsa)
  if (!abrupt) {
    const byPhoneSuccess = await db
      .collection(SUCCESS_COLLECTION)
      .doc(`phone_${ten}`)
      .get()
      .catch(() => null);
    if (byPhoneSuccess && byPhoneSuccess.exists) {
      const createdMs = byPhoneSuccess.data()?.created_at?.toMillis?.() || 0;
      const startMs = startUnix ? startUnix * 1000 : Date.now();
      if (createdMs && Math.abs(createdMs - startMs) < 45 * 60 * 1000) {
        await clearFailedPhoneOrderMirror(db, conversationId);
        await db
          .collection(FAILED_COLLECTION)
          .doc(conversationId)
          .set(
            {
              status: 'converted',
              order_id: byPhoneSuccess.data()?.order_id || null,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          )
          .catch(() => null);
        return {
          skipped: true,
          reason: 'success_by_phone',
          orderId: byPhoneSuccess.data()?.order_id,
        };
      }
    }
  }

  // Eski başarılı siparişler (conversation_id kaydı yoksa): aynı numarada yakın zamanda tamamlanmış telefon siparişi
  if (startUnix && !abrupt) {
    const windowStart = admin.firestore.Timestamp.fromMillis(
      (startUnix - 5 * 60) * 1000,
    );
    const windowEnd = admin.firestore.Timestamp.fromMillis(
      (startUnix + duration + 15 * 60) * 1000,
    );
    const nearOrders = await db
      .collection('orders')
      .where('customer_phone_digits', '==', ten)
      .where('order_source', '==', 'phone')
      .where('created_at', '>=', windowStart)
      .where('created_at', '<=', windowEnd)
      .limit(8)
      .get()
      .catch(() => null);
    if (nearOrders && !nearOrders.empty) {
      const done = nearOrders.docs.find((d) => {
        const data = d.data() || {};
        if (data.phone_failed === true) return false;
        if (String(data.status || '') === 'cancelled' && !data.items?.length) {
          return false;
        }
        return Array.isArray(data.items) && data.items.length > 0;
      });
      if (done) {
        await db
          .collection(SUCCESS_COLLECTION)
          .doc(conversationId)
          .set(
            {
              conversation_id: conversationId,
              order_id: done.id,
              phone_digits: ten,
              inferred: true,
              created_at: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        await db
          .collection(FAILED_COLLECTION)
          .doc(conversationId)
          .set(
            {
              status: 'converted',
              order_id: done.id,
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          )
          .catch(() => null);
        await clearFailedPhoneOrderMirror(db, conversationId);
        return { skipped: true, reason: 'matched_existing_order', orderId: done.id };
      }
    }
  }

  const existing = await db.collection(FAILED_COLLECTION).doc(conversationId).get();
  if (existing.exists) {
    const st = String(existing.data()?.status || '');
    if (st === 'dismissed' || st === 'called_back' || st === 'converted') {
      // Abrupt demote sonrası yeniden pending yazılabilir
      if (!(abrupt && st === 'converted')) {
        await clearFailedPhoneOrderMirror(db, conversationId);
        return { skipped: true, reason: 'already_handled', id: conversationId };
      }
    }
  }

  const known = await findCustomerByPhone(db, ten);
  const notes = transcriptNotesFromConversation(detail);
  const analysis = detail.analysis || {};
  const now = admin.firestore.FieldValue.serverTimestamp();
  const createdAt = startUnix
    ? admin.firestore.Timestamp.fromMillis(startUnix * 1000)
    : now;

  // Demote edilmiş sipariş varsa aynayı boş yazma; asıl sipariş zaten listede
  let demotedOrderId = null;
  if (abrupt) {
    const nearDemoted = await db
      .collection('orders')
      .where('phone_conversation_id', '==', conversationId)
      .where('phone_failed', '==', true)
      .limit(1)
      .get()
      .catch(() => null);
    if (nearDemoted && !nearDemoted.empty) {
      demotedOrderId = nearDemoted.docs[0].id;
    }
  }

  const doc = {
    id: conversationId,
    conversation_id: conversationId,
    phone_digits: ten,
    phone_display: formatDisplayPhone(ten),
    customer_name:
      known?.name ||
      known?.customer_name ||
      known?.company ||
      '',
    company: known?.company || '',
    address: known?.last_address || known?.address || '',
    notes: abrupt
      ? [FAILED_CALL_NOTE, notes].filter(Boolean).join('\n').slice(0, 800)
      : notes,
    transcript_summary: String(analysis.transcript_summary || '').trim(),
    call_summary_title: String(analysis.call_summary_title || '').trim(),
    call_duration_secs: duration,
    termination_reason: String(meta.termination_reason || ''),
    call_successful: String(analysis.call_successful || ''),
    abrupt: abrupt === true,
    order_id: demotedOrderId || (existing.exists ? existing.data()?.order_id : null) || null,
    status: 'pending',
    updated_at: now,
  };
  if (!existing.exists) {
    doc.created_at = createdAt;
  }

  await db.collection(FAILED_COLLECTION).doc(conversationId).set(doc, {
    merge: true,
  });

  if (demotedOrderId) {
    return { ok: true, id: conversationId, orderId: demotedOrderId, demoted: true };
  }

  const mirrorId = await upsertFailedPhoneOrderMirror(db, {
    conversationId,
    tenDigits: ten,
    customerName: doc.customer_name,
    address: doc.address,
    notes: FAILED_CALL_NOTE,
    createdAt: existing.exists ? existing.data()?.created_at || createdAt : createdAt,
  });

  return { ok: true, id: conversationId, orderId: mirrorId, abrupt: abrupt === true };
}

async function syncFailedPhoneOrdersFromElevenLabs(db, { pageSize = 25 } = {}) {
  const { getElevenLabsConfig } = require('./elevenlabs_config');
  const { apiKey } = getElevenLabsConfig();
  if (!apiKey) return { synced: 0, created: 0, error: 'elevenlabs_api_key_missing' };

  const list = await elevenLabsHttpsJson(
    'GET',
    `/v1/convai/conversations?agent_id=${encodeURIComponent(AGENT_ID)}&page_size=${pageSize}`,
    apiKey,
  );
  if (list.status >= 400) {
    return {
      synced: 0,
      created: 0,
      error: 'elevenlabs_list_failed',
      detail: list.json,
    };
  }

  const conversations = list.json?.conversations || [];
  let created = 0;
  let synced = 0;
  const cutoffUnix = Math.floor(Date.now() / 1000) - 48 * 60 * 60;
  for (const row of conversations) {
    if (String(row.status || '') !== 'done') continue;
    const start = Number(row.start_time_unix_secs || 0);
    if (start && start < cutoffUnix) continue;
    const id = row.conversation_id;
    if (!id) continue;
    const detailRes = await elevenLabsHttpsJson(
      'GET',
      `/v1/convai/conversations/${encodeURIComponent(id)}`,
      apiKey,
    );
    if (detailRes.status >= 400 || !detailRes.json) continue;
    const result = await upsertFailedPhoneOrderFromDetail(db, detailRes.json);
    synced += 1;
    if (result.ok) created += 1;
  }
  return { synced, created };
}

/** ElevenLabs post-call webhook (transcript) */
async function handlePhoneCallEnded(req, res) {
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
    const type = String(body.type || '').trim();
    // Workspace webhook wrapper veya düz conversation payload
    const detail =
      body.data && typeof body.data === 'object'
        ? body.data
        : body.conversation_id
          ? body
          : null;
    console.log('phoneCallEnded_in', {
      type,
      conversationId: detail?.conversation_id || null,
    });
    if (!detail || !detail.conversation_id) {
      res.status(200).json({ ok: true, skipped: true, reason: 'no_data' });
      return;
    }
    if (type && type !== 'post_call_transcription') {
      res.status(200).json({ ok: true, skipped: true, reason: 'ignored_type' });
      return;
    }
    const db = admin.firestore();
    const result = await upsertFailedPhoneOrderFromDetail(db, detail);
    await upsertPhoneCallLog(db, detail, {
      orderId: result.orderId || null,
      failed: result.ok === true || result.demoted === true,
      abrupt: result.abrupt === true || result.demoted === true,
      outcome:
        result.skipped &&
        (result.reason === 'already_success' ||
          result.reason === 'success_by_phone' ||
          result.reason === 'matched_existing_order')
          ? 'success'
          : result.ok
            ? 'failed'
            : result.skipped
              ? 'skipped'
              : 'failed',
    }).catch((e) => console.warn('phone_call_log_failed', e.message));
    res.status(200).json({ ok: true, ...result });
  } catch (e) {
    console.error('phoneCallEnded', e.message);
    // ElevenLabs retry etmesin diye 200
    res.status(200).json({ ok: false, error: e.message });
  }
}

async function handleListFailedPhoneOrders(req, res) {
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
    const body = req.method === 'POST' ? readJsonBody(req) : req.query || {};
    const sync = body.sync !== false && body.sync !== 'false';
    let syncResult = null;
    if (sync) {
      syncResult = await syncFailedPhoneOrdersFromElevenLabs(db);
      await closeStaleLiveDrafts(db).catch(() => 0);
    }

    const snap = await db
      .collection(FAILED_COLLECTION)
      .orderBy('created_at', 'desc')
      .limit(80)
      .get()
      .catch(async () =>
        db.collection(FAILED_COLLECTION).limit(80).get(),
      );

    const statusFilter = String(body.status || '').trim();
    const orders = snap.docs
      .map((d) => {
        const data = d.data() || {};
        const created = data.created_at;
        return {
          id: d.id,
          ...data,
          created_at:
            created && created.toDate
              ? created.toDate().toISOString()
              : created || null,
          updated_at:
            data.updated_at && data.updated_at.toDate
              ? data.updated_at.toDate().toISOString()
              : data.updated_at || null,
        };
      })
      .filter((o) =>
        statusFilter ? String(o.status || '') === statusFilter : true,
      );

    res.status(200).json({
      ok: true,
      orders,
      sync: syncResult,
    });
  } catch (e) {
    console.error('listFailedPhoneOrders', e.message);
    res.status(500).json({ error: 'list_failed', message: e.message });
  }
}

async function handleUpdateFailedPhoneOrder(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST' && req.method !== 'PATCH') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    assertSecret(req);
    const body = readJsonBody(req);
    const id = String(body.id || body.conversationId || body.conversation_id || '').trim();
    if (!id) {
      res.status(400).json({ error: 'id_required' });
      return;
    }
    const status = String(body.status || '').trim();
    const allowed = new Set([
      'pending',
      'called_back',
      'dismissed',
      'converted',
    ]);
    if (status && !allowed.has(status)) {
      res.status(400).json({ error: 'invalid_status' });
      return;
    }
    const patch = {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (status) patch.status = status;
    if (body.adminNote != null || body.admin_note != null) {
      patch.admin_note = String(body.adminNote || body.admin_note || '').trim();
    }
    if (status === 'called_back') {
      patch.callback_at = admin.firestore.FieldValue.serverTimestamp();
    }
    const db = admin.firestore();
    await db.collection(FAILED_COLLECTION).doc(id).set(patch, { merge: true });
    if (
      status === 'dismissed' ||
      status === 'called_back' ||
      status === 'converted'
    ) {
      await clearFailedPhoneOrderMirror(db, id);
    } else if (status === 'pending') {
      const snap = await db.collection(FAILED_COLLECTION).doc(id).get();
      const data = snap.data() || {};
      const ten = String(data.phone_digits || '').trim();
      if (ten) {
        await upsertFailedPhoneOrderMirror(db, {
          conversationId: id,
          tenDigits: ten,
          customerName: data.customer_name,
          address: data.address,
          notes: data.notes,
          createdAt: data.created_at,
        });
      }
    }
    res.status(200).json({ ok: true, id, status: status || null });
  } catch (e) {
    const code = e.code || 'update_failed';
    const status = code === 'unauthorized' ? 401 : 500;
    console.error('updateFailedPhoneOrder', code, e.message);
    res.status(status).json({ error: code });
  }
}

function transcriptTurnsFromDetail(detail) {
  const turns = [];
  for (const turn of detail.transcript || []) {
    const role = String(turn.role || '').trim();
    if (role !== 'user' && role !== 'agent') continue;
    const message = String(turn.message || '').trim();
    if (!message) continue;
    turns.push({
      role,
      message: message.slice(0, 2000),
      time_in_call_secs: turn.time_in_call_secs ?? null,
    });
  }
  return turns;
}

/**
 * Her görüşmenin tam konuşma logu (başarılı + başarısız).
 */
async function upsertPhoneCallLog(db, detail, extra = {}) {
  const conversationId = String(detail.conversation_id || '').trim();
  if (!conversationId) return null;
  const meta = detail.metadata || {};
  const analysis = detail.analysis || {};
  const ten = phoneFromConversationDetail(detail);
  const turns = transcriptTurnsFromDetail(detail);
  const startUnix = Number(meta.start_time_unix_secs || 0);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const outcome =
    extra.outcome ||
    (extra.orderId && !extra.failed
      ? 'success'
      : extra.failed || extra.abrupt
        ? 'failed'
        : String(analysis.call_successful || '').toLowerCase() === 'success'
          ? 'success'
          : 'failed');

  const doc = {
    id: conversationId,
    conversation_id: conversationId,
    phone_digits: ten || null,
    phone_display: ten ? formatDisplayPhone(ten) : null,
    outcome,
    order_id: extra.orderId || null,
    call_duration_secs: Number(meta.call_duration_secs || 0) || 0,
    termination_reason: String(meta.termination_reason || ''),
    call_successful: String(analysis.call_successful || ''),
    transcript_summary: String(analysis.transcript_summary || '').trim(),
    call_summary_title: String(analysis.call_summary_title || '').trim(),
    transcript: turns,
    notes: transcriptNotesFromConversation(detail),
    abrupt: extra.abrupt === true,
    updated_at: now,
  };
  if (startUnix) {
    doc.started_at = admin.firestore.Timestamp.fromMillis(startUnix * 1000);
  }
  await db.collection(CALL_LOGS_COLLECTION).doc(conversationId).set(doc, {
    merge: true,
  });
  return conversationId;
}

async function findLatestActivePhoneOrder(db, tenDigits) {
  if (!tenDigits) return null;
  const snap = await db
    .collection('orders')
    .where('customer_phone_digits', '==', tenDigits)
    .where('order_source', '==', 'phone')
    .orderBy('created_at', 'desc')
    .limit(12)
    .get()
    .catch(() => null);
  if (!snap || snap.empty) {
    // index yoksa fallback
    const alt = await db
      .collection('orders')
      .where('customer_phone_digits', '==', tenDigits)
      .where('order_source', '==', 'phone')
      .limit(20)
      .get()
      .catch(() => null);
    if (!alt || alt.empty) return null;
    const rows = alt.docs
      .map((d) => ({ id: d.id, ...(d.data() || {}) }))
      .sort((a, b) => {
        const am = a.created_at?.toMillis?.() || 0;
        const bm = b.created_at?.toMillis?.() || 0;
        return bm - am;
      });
    return (
      rows.find(
        (o) =>
          o.phone_failed !== true &&
          String(o.status || '') !== 'cancelled' &&
          String(o.status || '') !== 'delivered' &&
          Array.isArray(o.items) &&
          o.items.length > 0,
      ) || null
    );
  }
  for (const d of snap.docs) {
    const o = { id: d.id, ...(d.data() || {}) };
    if (o.phone_failed === true) continue;
    if (String(o.status || '') === 'cancelled') continue;
    if (String(o.status || '') === 'delivered') continue;
    if (!Array.isArray(o.items) || !o.items.length) continue;
    return o;
  }
  return null;
}

async function handleCancelPhoneOrder(req, res) {
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
    assertSecret(req);
    const body = readJsonBody(req);
    const ten = normalizeTrPhone(
      body.customerPhone ||
        body.phone ||
        body.system__caller_id ||
        body.caller_id,
    );
    const reason = String(body.reason || body.cancelReason || body.cancel_reason || '')
      .trim()
      .slice(0, 400);
    if (!ten) {
      res.status(400).json({
        ok: false,
        error: 'invalid_phone',
        agentHint: 'Telefon yok. lookup_phone_customer sonrası tekrar dene.',
      });
      return;
    }
    if (!reason || reason.length < 2) {
      res.status(400).json({
        ok: false,
        error: 'reason_required',
        agentHint:
          'İptal sebebini sor: "İptal sebebinizi ne olarak kaydedeyim?" Cevabı alıp cancel_phone_order’ı reason ile tekrar çağır.',
      });
      return;
    }

    const db = admin.firestore();
    let order =
      (body.orderId || body.order_id
        ? await db
            .collection('orders')
            .doc(String(body.orderId || body.order_id).trim())
            .get()
            .then((s) => (s.exists ? { id: s.id, ...s.data() } : null))
        : null) || (await findLatestActivePhoneOrder(db, ten));

    if (!order) {
      res.status(404).json({
        ok: false,
        error: 'order_not_found',
        agentHint:
          'Aktif sipariş bulunamadı. Müşteriye nazikçe söyle; end_call.',
      });
      return;
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const noteLine = `Sipariş iptal — sebep: ${reason}`;
    const prevNote = String(order.order_note || '').trim();
    const stamps = { ...(order.status_timestamps || {}) };
    stamps.cancelled = now;

    await db
      .collection('orders')
      .doc(order.id)
      .set(
        {
          status: 'cancelled',
          phone_failed: false,
          phone_incomplete: false,
          phone_cancel_reason: reason,
          phone_cancel_print_pending: true,
          order_note: prevNote ? `${prevNote}\n${noteLine}` : noteLine,
          updated_at: now,
          status_timestamps: stamps,
          status_actor_names: {
            ...(order.status_actor_names || {}),
            cancelled: 'Telefon AI',
          },
        },
        { merge: true },
      );

    const conversationId = String(
      body.conversationId ||
        body.conversation_id ||
        body.system__conversation_id ||
        order.phone_conversation_id ||
        '',
    ).trim();
    if (conversationId) {
      await db.collection(SUCCESS_COLLECTION).doc(conversationId).delete().catch(() => null);
    }
    await db.collection(SUCCESS_COLLECTION).doc(`phone_${ten}`).delete().catch(() => null);

    res.status(200).json({
      ok: true,
      orderId: order.id,
      orderNumber: order.order_number || null,
      reason,
      agentHint:
        'İptal kaydedildi ve fiş basılacak. Müşteriye: "Siparişiniz iptal edildi." de; end_call.',
    });
  } catch (e) {
    const code = e.code || 'cancel_failed';
    const status = code === 'unauthorized' ? 401 : 500;
    console.error('cancelPhoneOrder', code, e.message);
    res.status(status).json({ error: code });
  }
}

async function handleInquirePhoneOrder(req, res) {
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
    assertSecret(req);
    const body = readJsonBody(req);
    const ten = normalizeTrPhone(
      body.customerPhone ||
        body.phone ||
        body.system__caller_id ||
        body.caller_id,
    );
    const customerSaid = String(
      body.customerSaid || body.customer_said || body.message || '',
    )
      .trim()
      .slice(0, 400);
    if (!ten) {
      res.status(400).json({
        ok: false,
        error: 'invalid_phone',
        agentHint: 'Telefon yok. lookup sonrası inquire_phone_order dene.',
      });
      return;
    }

    const db = admin.firestore();
    const order = await findLatestActivePhoneOrder(db, ten);
    if (!order) {
      res.status(404).json({
        ok: false,
        error: 'order_not_found',
        minutesSinceOrder: null,
        agentHint:
          'Aktif sipariş yok. Nazikçe söyle; yeni sipariş almak isterse normal akışa geç.',
      });
      return;
    }

    const createdMs = order.created_at?.toMillis?.() || Date.now();
    const minutesSinceOrder = Math.max(
      0,
      Math.round((Date.now() - createdMs) / 60000),
    );
    const now = admin.firestore.FieldValue.serverTimestamp();
    const inquiryNote =
      `Siparişin nerede kaldığını sordu` +
      (customerSaid ? `: ${customerSaid}` : '');

    await db
      .collection('orders')
      .doc(order.id)
      .set(
        {
          phone_status_inquiry: true,
          phone_status_inquiry_at: now,
          phone_status_inquiry_note: inquiryNote,
          phone_status_inquiry_minutes: minutesSinceOrder,
          updated_at: now,
        },
        { merge: true },
      );

    res.status(200).json({
      ok: true,
      orderId: order.id,
      orderNumber: order.order_number || null,
      status: order.status || 'received',
      minutesSinceOrder,
      customerName: order.customer_name || null,
      agentHint:
        `Sipariş ${minutesSinceOrder} dk önce alındı. Müşteriye: ` +
        `"Siparişinizden ${minutesSinceOrder} dakika geçmiş. Hemen yetkilileri bilgilendiriyorum." de; end_call.`,
    });
  } catch (e) {
    const code = e.code || 'inquire_failed';
    const status = code === 'unauthorized' ? 401 : 500;
    console.error('inquirePhoneOrder', code, e.message);
    res.status(status).json({ error: code });
  }
}

async function handleListPhoneCallLogs(req, res) {
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
    const body = req.method === 'POST' ? readJsonBody(req) : req.query || {};
    const outcome = String(body.outcome || '').trim();
    let snap = await db
      .collection(CALL_LOGS_COLLECTION)
      .orderBy('updated_at', 'desc')
      .limit(100)
      .get()
      .catch(() => null);
    if (!snap) {
      snap = await db.collection(CALL_LOGS_COLLECTION).limit(100).get();
    }
    const logs = snap.docs
      .map((d) => {
        const data = d.data() || {};
        return {
          id: d.id,
          ...data,
          started_at:
            data.started_at && data.started_at.toDate
              ? data.started_at.toDate().toISOString()
              : data.started_at || null,
          updated_at:
            data.updated_at && data.updated_at.toDate
              ? data.updated_at.toDate().toISOString()
              : data.updated_at || null,
        };
      })
      .filter((o) => (outcome ? String(o.outcome || '') === outcome : true));
    res.status(200).json({ ok: true, logs });
  } catch (e) {
    console.error('listPhoneCallLogs', e.message);
    res.status(500).json({ error: e.message });
  }
}

module.exports = {
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
  normalizeTrPhone,
  upsertPhoneCustomer,
  COLLECTION,
  FAILED_COLLECTION,
  CALL_LOGS_COLLECTION,
};
