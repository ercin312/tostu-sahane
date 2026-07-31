/**
 * Türkiye (UTC+3) mesai saatleri — telefon asistanı.
 */

const DAY_KEYS = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
const DAY_LABELS_TR = {
  sun: 'Pazar',
  mon: 'Pazartesi',
  tue: 'Salı',
  wed: 'Çarşamba',
  thu: 'Perşembe',
  fri: 'Cuma',
  sat: 'Cumartesi',
};

const DEFAULT_CLOSED_MESSAGE =
  'Şu an kapalıyız, sipariş alamıyoruz. Mesai saatlerimiz içinde tekrar arayın. İyi günler dilerim.';

function parseHm(raw) {
  const m = String(raw || '')
    .trim()
    .match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h < 0 || h > 23 || min < 0 || min > 59) return null;
  return h * 60 + min;
}

function formatHm(minutes) {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function turkeyWallClock(now = new Date()) {
  // Sabit UTC+3 (DST yok). getUTC* ile ortam timezone'undan bağımsız.
  const tr = new Date(now.getTime() + 3 * 60 * 60 * 1000);
  const minutes = tr.getUTCHours() * 60 + tr.getUTCMinutes();
  return {
    dayKey: DAY_KEYS[tr.getUTCDay()],
    minutes,
    dateLabel: `${tr.getUTCFullYear()}-${String(tr.getUTCMonth() + 1).padStart(2, '0')}-${String(tr.getUTCDate()).padStart(2, '0')} ${formatHm(minutes)}`,
  };
}

function defaultDaySchedule() {
  return { open: '10:00', close: '23:00', closed: false };
}

function normalizeBusinessHours(raw) {
  const src = raw && typeof raw === 'object' ? raw : {};
  const scheduleIn = src.schedule && typeof src.schedule === 'object' ? src.schedule : {};
  const schedule = {};
  for (const key of DAY_KEYS) {
    const day = scheduleIn[key] || {};
    const closed = day.closed === true;
    const open = String(day.open || '10:00').trim();
    const close = String(day.close || '23:00').trim();
    schedule[key] = {
      open: parseHm(open) != null ? open : '10:00',
      close: parseHm(close) != null ? close : '23:00',
      closed,
    };
  }
  return {
    enabled: src.enabled === true,
    timezone: 'Europe/Istanbul',
    schedule,
    closedMessage: String(
      src.closedMessage || src.closed_message || DEFAULT_CLOSED_MESSAGE,
    ).trim() || DEFAULT_CLOSED_MESSAGE,
  };
}

/**
 * @returns {{ open: boolean, enabled: boolean, dayKey: string, todayLabel: string, todayHours: string|null, closedMessage: string, nowTr: string }}
 */
function evaluateStoreOpen(businessHours, now = new Date()) {
  const hours = normalizeBusinessHours(businessHours);
  const wall = turkeyWallClock(now);
  const day = hours.schedule[wall.dayKey] || defaultDaySchedule();
  const todayLabel = DAY_LABELS_TR[wall.dayKey] || wall.dayKey;
  const openMin = parseHm(day.open);
  const closeMin = parseHm(day.close);
  let todayHours = null;
  if (!day.closed && openMin != null && closeMin != null) {
    todayHours = `${formatHm(openMin)}-${formatHm(closeMin)}`;
  }

  if (!hours.enabled) {
    return {
      open: true,
      enabled: false,
      dayKey: wall.dayKey,
      todayLabel,
      todayHours,
      closedMessage: hours.closedMessage,
      nowTr: wall.dateLabel,
    };
  }

  let open = false;
  if (!day.closed && openMin != null && closeMin != null) {
    if (closeMin > openMin) {
      open = wall.minutes >= openMin && wall.minutes < closeMin;
    } else if (closeMin < openMin) {
      // gece yarısını geçen mesai (örn. 18:00–02:00)
      open = wall.minutes >= openMin || wall.minutes < closeMin;
    }
  }

  return {
    open,
    enabled: true,
    dayKey: wall.dayKey,
    todayLabel,
    todayHours,
    closedMessage: hours.closedMessage,
    nowTr: wall.dateLabel,
  };
}

function businessHoursPromptSection(businessHours) {
  const hours = normalizeBusinessHours(businessHours);
  if (!hours.enabled) {
    return (
      '\n## Mesai saatleri\n' +
      'Mesai kısıtı kapalı; her zaman sipariş alabilirsin.\n'
    );
  }
  const lines = [
    '',
    '## Mesai saatleri (Türkiye saati, UTC+3)',
    'lookup_phone_customer cevabında storeOpen gelir.',
    'storeOpen=false ise: kapalı mesajını söyle, sipariş ALMA, end_call.',
    'storeOpen=true ise: normal akışa devam et.',
    'Kapalıyken create_phone_order çağırma.',
    `Kapalı mesajı: "${hours.closedMessage}"`,
    'Haftalık program:',
  ];
  for (const key of DAY_KEYS) {
    const d = hours.schedule[key];
    const label = DAY_LABELS_TR[key];
    if (d.closed) {
      lines.push(`- ${label}: kapalı`);
    } else {
      lines.push(`- ${label}: ${d.open}-${d.close}`);
    }
  }
  lines.push('');
  return lines.join('\n');
}

module.exports = {
  DAY_KEYS,
  DAY_LABELS_TR,
  DEFAULT_CLOSED_MESSAGE,
  normalizeBusinessHours,
  evaluateStoreOpen,
  businessHoursPromptSection,
  turkeyWallClock,
};
