/**
 * Telefon AI prompt + ElevenLabs sync.
 * Eğitim örnekleri: meta/phone_ai_training
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const admin = require('firebase-admin');
const { getElevenLabsConfig, loadDotEnvOnce } = require('./elevenlabs_config');
const {
  normalizeBusinessHours,
  businessHoursPromptSection,
} = require('./phone_business_hours');

loadDotEnvOnce();

const AGENT_ID =
  process.env.ELEVENLABS_AGENT_ID || 'agent_2201kycqaz84fraamk0gp9qxz7hv';
const META_DOC = 'phone_ai_training';
const VOICE_ID = process.env.ELEVENLABS_VOICE_ID || 'N0wraTTB0pquzsz3DLG8';
const BASE =
  process.env.PHONE_FN_BASE ||
  'https://us-central1-tostusahane-e4e71.cloudfunctions.net';

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

function assertSecret(req) {
  const expected = process.env.PHONE_ORDER_SECRET || '';
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

function loadBasePrompt() {
  const p = path.join(__dirname, 'agent_prompt_tostu.md');
  let text = fs.readFileSync(p, 'utf8');
  const hasFullMenu = (text.match(/^- w_/gm) || []).length > 20;
  if (!hasFullMenu) {
    try {
      const menu = JSON.parse(
        fs.readFileSync(path.join(__dirname, 'phone_menu_catalog.json'), 'utf8'),
      );
      const head =
        text.split(/## Menü[^\n]*/)[0] +
        '## Menü (sessiz — productId | ad | fiyat)\n';
      text =
        head +
        menu.map((x) => `- ${x.id} | ${x.name} | ${x.price}`).join('\n') +
        '\n';
    } catch (e) {
      console.warn('phone_menu_catalog_load_failed', e.message);
    }
  }
  return text.trimEnd();
}

function trainingSection(examples) {
  if (!Array.isArray(examples) || examples.length === 0) return '';
  const lines = [
    '',
    '## Yönetici eğitim örnekleri (öncelikli)',
    'Aşağıdakilerde de SADECE Türkçe konuş; İngilizce düşünce okuma.',
    'Müşteri şöyle derse / sorarsa, aşağıdaki gibi cevap ver (kısa, net):',
  ];
  for (const ex of examples) {
    const when = String(ex.whenCustomerSays || ex.when || '').trim();
    const then = String(ex.assistantShould || ex.then || '').trim();
    if (!when || !then) continue;
    lines.push(`Müşteri: ${when}`);
    lines.push(`Sen: ${then}`);
    lines.push('');
  }
  return lines.join('\n');
}

function adminPriorityBlock(training) {
  const style = String(training.styleNotes || '').trim();
  const lines = [
    '',
    '# YÖNETİCİ KURALLARI (EN YÜKSEK ÖNCELİK — ÇAKIŞMADA BUNLAR KAZANIR)',
    'Aşağıdaki yönetici metni, bu prompttaki diğer tüm bölümlerden (menü, örnekler, varsayılan akış) ÖNCE gelir.',
    'Yönetici kuralı ile başka kural çakışırsa YALNIZCA yönetici kuralını uygula.',
    'Teknik istisna (bozulamaz): tool çağrıları sessiz; create_phone_order olmadan “alındı” deme; İngilizce ses yok.',
    '',
  ];
  if (style) {
    lines.push('## Yönetici üslup ve iş kuralları (AYNEN UYGULA)');
    lines.push(style);
  } else {
    lines.push('## Yönetici üslup');
    lines.push('Net, yüksek sesli, sipariş odaklı konuş.');
  }
  lines.push('');
  lines.push('## Sabit paket kuralları (her zaman)');
  lines.push(
    '- Çay (w_cay) paket/telefon teslimatta GÖNDERİLMEZ. İstenirse: “Çayı paket olarak gönderemiyoruz.” de; alternatif içecek öner.',
  );
  lines.push(
    '- Açık ayran (w_acik_ayran) paket GİTMEZ. Ayran isterse kapalı ayran (w_ayran) yaz. “Açık ayran paket gitmiyor, kapalı ayran yazarım.”',
  );
  lines.push(
    '- Kayıtlı müşteri: İSİM SORMA. Yalnızca “Aynı adrese mi göndereyim?” Evet → useSavedAddress=true. Farklı → yeni adres (useSavedAddress=false).',
  );
  lines.push('');
  return lines.join('\n');
}

function adminRulesFooter(training) {
  const style = String(training.styleNotes || '').trim();
  if (!style) return '';
  return (
    '\n\n# YÖNETİCİ KURALLARI (TEKRAR — UNUTMA)\n' +
    'Çakışmada bu metin kazanır:\n' +
    style +
    '\n'
  );
}

function buildPrompt(training) {
  const base = loadBasePrompt();
  const hoursBlock = businessHoursPromptSection(training.businessHours);
  const examples = trainingSection(training.examples);
  // Yönetici kuralları başta + sonda (uzun menüde ezilmesin).
  return (
    `${adminPriorityBlock(training)}${base}${hoursBlock}${examples}${adminRulesFooter(training)}\n`.trim() +
    '\n'
  );
}

function elevenRequest(method, urlPath, body, apiKey) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const req = https.request(
      {
        hostname: 'api.elevenlabs.io',
        path: urlPath,
        method,
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
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

function webhookToolConfig(name, description, url, bodySchema, extras = {}) {
  return {
    type: 'webhook',
    name,
    description,
    response_timeout_secs: extras.response_timeout_secs || 15,
    disable_interruptions: extras.disable_interruptions === true,
    force_pre_tool_speech: false,
    assignments: extras.assignments || [],
    execution_mode: 'immediate',
    api_schema: {
      url,
      method: 'POST',
      request_headers: {
        'Content-Type': 'application/json',
      },
      request_body_schema: bodySchema,
    },
  };
}

function phoneToolConfigs() {
  return [
    webhookToolConfig(
      'lookup_phone_customer',
      'Görüşmenin İLK çağrısı — ZORUNLU. Sessiz. Sonucu sesli okuma. Taslak sipariş açMAZ.',
      `${BASE}/lookupPhoneCustomer`,
      {
        type: 'object',
        description: 'Lookup body',
        properties: {
          phone: {
            type: 'string',
            dynamic_variable: 'system__caller_id',
          },
        },
        required: [],
      },
      {
        assignments: [
          {
            source: 'response',
            dynamic_variable: 'known_caller_phone',
            value_path: 'phone',
          },
        ],
      },
    ),
    webhookToolConfig(
      'create_phone_order',
      'ZORUNLU: sipariş TAM bitince BİR KEZ çağır (isim+adres+tüm items hazır). ' +
        'Görüşme ortasında / ürün alırken ASLA çağırma. ' +
        'Kayıtlı müşteriye İSİM SORMA. Kayıtsızda useSavedAddress=false + customerName + address ZORUNLU. ' +
        'ok:true gelmeden “alındı” deme. Ara kayıt YASAK. Açık ayran/çay paket YOK.',
      `${BASE}/createPhoneOrder`,
      {
        type: 'object',
        description: 'Order body',
        properties: {
          conversationId: {
            type: 'string',
            dynamic_variable: 'system__conversation_id',
          },
          customerPhone: {
            type: 'string',
            dynamic_variable: 'system__caller_id',
          },
          customerName: { type: 'string', description: 'İsim (yalnız kayıtsız)' },
          company: { type: 'string', description: 'Firma' },
          address: { type: 'string', description: 'Teslimat adresi' },
          deliveryDirections: { type: 'string', description: 'Yol tarifi' },
          useSavedAddress: {
            type: 'boolean',
            description: 'Kayıtlı aynı adres onayı sonrası true',
          },
          paymentMethod: {
            type: 'string',
            constant_value: 'cashOnDelivery',
          },
          orderNote: { type: 'string', description: 'Genel sipariş notu' },
          items: {
            type: 'array',
            description: 'Tüm kalemler (tek seferde)',
            items: {
              type: 'object',
              description: 'Kalem',
              properties: {
                productId: { type: 'string', description: 'Menü productId' },
                productName: { type: 'string', description: 'Ürün adı' },
                unitPrice: { type: 'number', description: 'Birim fiyat' },
                quantity: { type: 'number', description: 'Adet' },
                note: {
                  type: 'string',
                  description: 'Kalem notu (örn. acılı)',
                },
              },
              required: ['productId', 'productName', 'unitPrice', 'quantity'],
            },
          },
        },
        required: ['items'],
      },
      {
        disable_interruptions: true,
        response_timeout_secs: 25,
      },
    ),
    webhookToolConfig(
      'cancel_phone_order',
      'Müşteri mevcut siparişi iptal etmek isterse. Önce "İptal sebebinizi ne olarak kaydedeyim?" sor. ' +
        'Sebebi reason ile gönder. Sessiz tool; ok:true gelince iptal edildi de.',
      `${BASE}/cancelPhoneOrder`,
      {
        type: 'object',
        description: 'Cancel body',
        properties: {
          conversationId: {
            type: 'string',
            dynamic_variable: 'system__conversation_id',
          },
          customerPhone: {
            type: 'string',
            dynamic_variable: 'system__caller_id',
          },
          reason: {
            type: 'string',
            description: 'Müşterinin iptal sebebi',
          },
          orderId: { type: 'string', description: 'Varsa sipariş id' },
        },
        required: ['reason'],
      },
      {
        disable_interruptions: true,
        response_timeout_secs: 20,
      },
    ),
    webhookToolConfig(
      'inquire_phone_order',
      'Müşteri "tostum nerede / siparişim nerede kaldı" derse çağır. ' +
        'Dakikayı söyle: "X dk olmuş, hemen yetkilileri bilgilendiriyorum." Sessiz tool.',
      `${BASE}/inquirePhoneOrder`,
      {
        type: 'object',
        description: 'Inquiry body',
        properties: {
          conversationId: {
            type: 'string',
            dynamic_variable: 'system__conversation_id',
          },
          customerPhone: {
            type: 'string',
            dynamic_variable: 'system__caller_id',
          },
          customerSaid: {
            type: 'string',
            description: 'Müşterinin nerede kaldı cümlesi',
          },
        },
        required: [],
      },
      {
        response_timeout_secs: 15,
      },
    ),
  ];
}

async function upsertWorkspaceTools(apiKey) {
  const configs = phoneToolConfigs();
  const list = await elevenRequest('GET', '/v1/convai/tools', null, apiKey);
  const existing = list.json?.tools || [];
  const byName = new Map(
    existing.map((t) => [t.tool_config?.name || t.name, t]),
  );
  const ids = [];
  for (const cfg of configs) {
    const prev = byName.get(cfg.name);
    if (prev?.id) {
      const res = await elevenRequest(
        'PATCH',
        `/v1/convai/tools/${prev.id}`,
        { tool_config: cfg },
        apiKey,
      );
      if (res.status >= 400) {
        console.error('tool_patch_failed', cfg.name, res.status, res.json);
        ids.push(prev.id);
      } else {
        ids.push(prev.id);
      }
    } else {
      const res = await elevenRequest(
        'POST',
        '/v1/convai/tools',
        { tool_config: cfg },
        apiKey,
      );
      if (res.status >= 400 || !res.json?.id) {
        const err = new Error('tool_create_failed');
        err.code = 'tool_create_failed';
        err.detail = res.json;
        throw err;
      }
      ids.push(res.json.id);
    }
  }
  return ids;
}

function resolveFirstMessage(training) {
  const custom = String(training.firstMessage || training.first_message || '').trim();
  if (custom) return custom;
  return 'Buyrun Tostu Şahane, ne siparişi vermek istersiniz?';
}

function agentPatchBody(promptText, training = {}, toolIds = []) {
  return {
    name: 'Tostu Sahane Telefon',
    conversation_config: {
      agent: {
        first_message: resolveFirstMessage(training),
        language: 'tr',
        prompt: {
          prompt: promptText,
          llm: 'gpt-4o',
          temperature: 0.2,
          // Legacy inline tools YASAK — yalnız tool_ids (ElevenLabs 2025+).
          tool_ids: toolIds,
          built_in_tools: {
            end_call: {
              name: 'end_call',
              description:
                'create_phone_order ok:true ve alındı cümlesinden SONRA bitir. ' +
                'Kapalıysa veya müşteri sipariş vermeden kapattıysa tool’suz end_call OK.',
              params: { system_tool_type: 'end_call' },
            },
          },
        },
      },
      asr: {
        quality: 'high',
        provider: 'scribe_realtime',
        keywords: [
          'tost',
          'kaşarlı',
          'karışık',
          'salçalı',
          'sade',
          'ayran',
          'sucuklu',
          'menemen',
          'adres',
          'kavurmalı',
          'içecek',
          'kola',
          'acılı',
          'acı',
        ],
      },
      vad: { background_voice_detection: true },
      turn: {
        turn_timeout: 4,
        mode: 'turn',
        turn_eagerness: 'eager',
        speculative_turn: true,
        soft_timeout_config: {
          timeout_seconds: -1,
          message: '.',
          use_llm_generated_message: false,
        },
      },
      tts: {
        model_id: 'eleven_v3_conversational',
        voice_id: VOICE_ID,
        expressive_mode: true,
        stability: 0.28,
        similarity_boost: 0.75,
        speed: 1.14,
        optimize_streaming_latency: 4,
      },
    },
    platform_settings: {
      overrides: {
        enable_conversation_initiation_client_data_from_webhook: true,
      },
    },
  };
}

function normalizeExamples(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((e, i) => ({
      id: String(e.id || `ex_${i + 1}`),
      whenCustomerSays: String(e.whenCustomerSays || e.when || '').trim(),
      assistantShould: String(e.assistantShould || e.then || '').trim(),
    }))
    .filter((e) => e.whenCustomerSays && e.assistantShould);
}

async function readTraining(db) {
  const snap = await db.collection('meta').doc(META_DOC).get();
  if (!snap.exists) {
    return {
      examples: [],
      styleNotes: '',
      businessHours: normalizeBusinessHours(null),
      updatedAt: null,
    };
  }
  const data = snap.data() || {};
  return {
    examples: normalizeExamples(data.examples),
    styleNotes: String(data.style_notes || data.styleNotes || ''),
    businessHours: normalizeBusinessHours(
      data.business_hours || data.businessHours,
    ),
    updatedAt: data.updated_at || null,
  };
}

async function writeTraining(db, { examples, styleNotes, businessHours }) {
  const payload = {
    examples: normalizeExamples(examples),
    style_notes: String(styleNotes || '').trim(),
    business_hours: normalizeBusinessHours(businessHours),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('meta').doc(META_DOC).set(payload, { merge: true });
  return readTraining(db);
}

async function ensureConversationInitWebhook(apiKey) {
  const headers = { 'Content-Type': 'application/json' };
  const secret = process.env.PHONE_ORDER_SECRET || '';
  if (secret) {
    headers['X-Phone-Order-Secret'] = secret;
  }
  const settingsBody = {
    conversation_initiation_client_data_webhook: {
      url: `${BASE}/phoneCallInit`,
      request_headers: headers,
    },
  };
  const res = await elevenRequest(
    'PATCH',
    '/v1/convai/settings',
    settingsBody,
    apiKey,
  );
  if (res.status >= 400) {
    console.error('ensureConversationInitWebhook_failed', res.status, res.json);
    return { ok: false, status: res.status, detail: res.json };
  }
  return { ok: true, url: `${BASE}/phoneCallInit` };
}

async function syncAgent(training) {
  const { apiKey, voiceId } = getElevenLabsConfig();
  if (!apiKey) {
    const err = new Error('elevenlabs_api_key_missing');
    err.code = 'elevenlabs_api_key_missing';
    throw err;
  }
  const toolIds = await upsertWorkspaceTools(apiKey);
  const prompt = buildPrompt(training);
  const body = agentPatchBody(prompt, training, toolIds);
  body.conversation_config.tts.voice_id = voiceId || VOICE_ID;
  const res = await elevenRequest(
    'PATCH',
    `/v1/convai/agents/${AGENT_ID}`,
    body,
    apiKey,
  );
  if (res.status >= 400) {
    const err = new Error(
      (res.json && res.json.detail && res.json.detail.message) ||
        'elevenlabs_patch_failed',
    );
    err.code = 'elevenlabs_patch_failed';
    err.detail = res.json;
    throw err;
  }
  const initWebhook = await ensureConversationInitWebhook(apiKey);
  return {
    ok: true,
    promptChars: prompt.length,
    agentId: AGENT_ID,
    toolIds,
    llm: 'gpt-4o',
    initWebhook,
  };
}

async function handleGetPhoneAiTraining(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }
  try {
    assertSecret(req);
    const training = await readTraining(admin.firestore());
    res.status(200).json({
      examples: training.examples,
      styleNotes: training.styleNotes,
      businessHours: training.businessHours,
      updatedAt: training.updatedAt,
    });
  } catch (e) {
    const status = e.code === 'unauthorized' ? 401 : 500;
    res.status(status).json({ error: e.code || 'get_failed' });
  }
}

async function handleSavePhoneAiTraining(req, res) {
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
    const db = admin.firestore();
    const training = await writeTraining(db, {
      examples: body.examples,
      styleNotes: body.styleNotes || body.style_notes,
      businessHours: body.businessHours || body.business_hours,
    });
    let sync = null;
    let syncError = null;
    try {
      sync = await syncAgent(training);
    } catch (e) {
      syncError = e.code || e.message;
      console.error('syncPhoneAiAgent', e.code, e.message, e.detail);
    }
    res.status(200).json({
      ok: true,
      examples: training.examples,
      styleNotes: training.styleNotes,
      businessHours: training.businessHours,
      synced: Boolean(sync),
      sync,
      syncError,
    });
  } catch (e) {
    const status = e.code === 'unauthorized' ? 401 : 500;
    console.error('savePhoneAiTraining', e.code, e.message);
    res.status(status).json({ error: e.code || 'save_failed' });
  }
}

async function handleSyncPhoneAiAgent(req, res) {
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
    const training = await readTraining(admin.firestore());
    const sync = await syncAgent(training);
    res.status(200).json({ ok: true, ...sync });
  } catch (e) {
    const status =
      e.code === 'unauthorized'
        ? 401
        : e.code === 'elevenlabs_api_key_missing'
          ? 503
          : 500;
    console.error('syncPhoneAiAgent', e.code, e.message);
    res.status(status).json({ error: e.code || 'sync_failed', detail: e.detail });
  }
}

module.exports = {
  handleGetPhoneAiTraining,
  handleSavePhoneAiTraining,
  handleSyncPhoneAiAgent,
  buildPrompt,
  syncAgent,
  readTraining,
};
