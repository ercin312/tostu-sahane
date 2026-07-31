(() => {
  const cfg = window.QR_MENU_CONFIG;
  const root = `https://firestore.googleapis.com/v1/projects/${cfg.projectId}/databases/(default)/documents`;

  const params = new URLSearchParams(location.search);
  const tableNumber = Math.max(
    1,
    parseInt(params.get('table') || params.get('masa') || '0', 10) || 0,
  );
  const branchId = params.get('branch') || cfg.defaultBranchId;

  const els = {
    brandTitle: document.getElementById('brandTitle'),
    loading: document.getElementById('loading'),
    homeBody: document.getElementById('homeBody'),
    tableChip: document.getElementById('tableChip'),
    featuredSection: document.getElementById('featuredSection'),
    featuredCarousel: document.getElementById('featuredCarousel'),
    catNav: document.getElementById('catNav'),
    productList: document.getElementById('productList'),
    viewHome: document.getElementById('viewHome'),
    viewDetail: document.getElementById('viewDetail'),
    btnHome: document.getElementById('btnHome'),
    btnDetailBack: document.getElementById('btnDetailBack'),
    detailBackLabel: document.getElementById('detailBackLabel'),
    detailMedia: document.getElementById('detailMedia'),
    detailTitle: document.getElementById('detailTitle'),
    detailPrice: document.getElementById('detailPrice'),
    detailDesc: document.getElementById('detailDesc'),
    btnCall: document.getElementById('btnCall'),
    garsonWrap: document.getElementById('garsonWrap'),
    toast: document.getElementById('toast'),
  };

  const DEFAULT_NAV = [
    { id: 'tost', label: 'Tostlar', enabled: true, sort_order: 0 },
    { id: 'sahanda', label: 'Sahandakiler', enabled: true, sort_order: 1 },
    { id: 'drink', label: 'İçecekler', enabled: true, sort_order: 2 },
    { id: 'snack', label: 'Atıştırmalık', enabled: true, sort_order: 3 },
    { id: 'extra', label: 'Ekstralar', enabled: true, sort_order: 4 },
  ];

  let sectionsCache = [];
  let activeKey = 'tost';
  let allItemsById = new Map();

  function decodeValue(v) {
    if (!v || typeof v !== 'object') return null;
    if ('stringValue' in v) return v.stringValue;
    if ('integerValue' in v) return Number(v.integerValue);
    if ('doubleValue' in v) return Number(v.doubleValue);
    if ('booleanValue' in v) return !!v.booleanValue;
    if ('nullValue' in v) return null;
    if ('arrayValue' in v) {
      return ((v.arrayValue && v.arrayValue.values) || []).map(decodeValue);
    }
    if ('mapValue' in v) {
      const fields = (v.mapValue && v.mapValue.fields) || {};
      const out = {};
      Object.keys(fields).forEach((k) => {
        out[k] = decodeValue(fields[k]);
      });
      return out;
    }
    return null;
  }

  function docToJson(doc) {
    const name = doc.name || '';
    const id = name.split('/').pop();
    const fields = doc.fields || {};
    const data = { id };
    Object.keys(fields).forEach((k) => {
      data[k] = decodeValue(fields[k]);
    });
    return data;
  }

  async function listCollection(collectionId, pageSize = 300) {
    const url = `${root}/${collectionId}?key=${encodeURIComponent(cfg.apiKey)}&pageSize=${pageSize}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`list_${collectionId}_failed_${res.status}`);
    const json = await res.json();
    return (json.documents || []).map(docToJson);
  }

  async function getDoc(path) {
    const url = `${root}/${path}?key=${encodeURIComponent(cfg.apiKey)}`;
    const res = await fetch(url);
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`get_${path}_failed_${res.status}`);
    return docToJson(await res.json());
  }

  async function loadMenuViaFunction() {
    if (!cfg.menuUrl) throw new Error('menu_url_missing');
    const res = await fetch(cfg.menuUrl, { method: 'GET' });
    if (!res.ok) throw new Error(`menu_fn_${res.status}`);
    const data = await res.json();
    if (!data || !Array.isArray(data.products)) {
      throw new Error('menu_fn_bad_payload');
    }
    return {
      settings: data.settings || {},
      products: data.products,
      extras: Array.isArray(data.extras) ? data.extras : [],
    };
  }

  async function loadMenuViaFirestore() {
    const [settings, products, extras] = await Promise.all([
      getDoc('meta/qr_menu_settings'),
      listCollection('products'),
      listCollection('catalog_extras').catch(() => []),
    ]);
    return { settings: settings || {}, products, extras };
  }

  async function loadMenu() {
    try {
      return await loadMenuViaFunction();
    } catch (e) {
      console.warn('menu function failed, fallback firestore', e);
    }
    return loadMenuViaFirestore();
  }

  function priceParts(n) {
    const v = Number(n || 0);
    const formatted = v.toLocaleString('tr-TR', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
    return { formatted, html: `<b>${formatted}</b> TL` };
  }

  function thumbSrc(raw) {
    if (!raw) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('base64:')) return `data:image/jpeg;base64,${raw.slice(7)}`;
    return null;
  }

  function showToast(msg) {
    els.toast.hidden = false;
    els.toast.textContent = msg;
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => {
      els.toast.hidden = true;
    }, 3200);
  }

  function productTitle(p) {
    return p.name || p.name_key || p.title || 'Ürün';
  }

  function productDesc(p) {
    return (p.description || p.description_key || '').trim();
  }

  function isHidden(id, settings) {
    return (settings.hidden_product_ids || []).includes(id);
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function mediaHtml(src, className) {
    if (src) {
      return `<img loading="lazy" class="${className || ''}" src="${src}" alt="" />`;
    }
    return `<div class="ph" aria-hidden="true"></div>`;
  }

  function showView(name) {
    els.viewHome.hidden = name !== 'home';
    els.viewDetail.hidden = name !== 'detail';
    if (name === 'home') window.scrollTo({ top: 0, behavior: 'auto' });
  }

  function renderProductRow(item, sectionKey, index) {
    const src = thumbSrc(item.image_url);
    const desc = productDesc(item) || ' ';
    const price = priceParts(item.price);
    return `<div class="lrc-item">
      <button type="button" class="lrc-hit" data-section="${sectionKey}" data-index="${index}">
        <div class="lrc-content">
          <div class="lrc-img">${mediaHtml(src, 'img_border')}</div>
          <div class="lrc-desc">
            <div class="lrc-title">${escapeHtml(productTitle(item))}</div>
            <div class="lrc-text">${escapeHtml(desc)}</div>
            <div class="lrc-button">
              <div class="lrcb-left" style="font-size:17px;">
                <span class="lhc like">${price.html}</span>
              </div>
              <div class="lrcb-right"></div>
              <div class="clear"></div>
            </div>
          </div>
        </div>
      </button>
    </div>`;
  }

  function bindProductRows(rootEl) {
    rootEl.querySelectorAll('.lrc-hit').forEach((btn) => {
      btn.addEventListener('click', () => {
        const section = sectionsCache.find((s) => s.key === btn.dataset.section);
        const item = section && section.items[Number(btn.dataset.index)];
        if (item) openDetail(item, section);
      });
    });
  }

  function selectCategory(key, scrollList = true) {
    const section = sectionsCache.find((s) => s.key === key) || sectionsCache[0];
    if (!section) {
      els.productList.innerHTML =
        '<div class="empty">Bu kategoride ürün yok.</div>';
      return;
    }
    activeKey = section.key;
    els.catNav.querySelectorAll('.cat-nav-btn').forEach((b) => {
      b.classList.toggle('active', b.dataset.key === activeKey);
    });
    if (!section.items.length) {
      els.productList.innerHTML =
        '<div class="empty">Bu kategoride ürün yok.</div>';
    } else {
      els.productList.innerHTML = section.items
        .map((item, i) => renderProductRow(item, section.key, i))
        .join('');
      bindProductRows(els.productList);
    }
    if (scrollList) {
      const nav = els.catNav;
      const top = nav.getBoundingClientRect().bottom + window.scrollY - 4;
      window.scrollTo({ top: Math.max(0, top - 56), behavior: 'smooth' });
    }
  }

  function openDetail(item, section) {
    if (section) activeKey = section.key;
    els.detailBackLabel.textContent = section ? section.title : 'Menü';
    const src = thumbSrc(item.image_url);
    els.detailMedia.innerHTML = mediaHtml(src);
    els.detailTitle.textContent = productTitle(item);
    els.detailPrice.innerHTML = priceParts(item.price).html;
    els.detailDesc.textContent =
      productDesc(item) || 'Lezzetli bir Tost-u Şahane seçimi.';
    showView('detail');
    window.scrollTo({ top: 0, behavior: 'auto' });
  }

  function showHome() {
    showView('home');
    selectCategory(activeKey || 'tost', false);
  }

  function resolveNavCategories(settings) {
    const raw = settings.nav_categories;
    if (Array.isArray(raw) && raw.length) {
      return raw
        .map((c, i) => ({
          id: String(c.id || '').trim(),
          label: String(c.label_tr || c.label || c.id || '').trim() || 'Kategori',
          enabled: c.enabled !== false,
          sort_order:
            typeof c.sort_order === 'number' ? c.sort_order : i,
        }))
        .filter((c) => c.id)
        .sort((a, b) => a.sort_order - b.sort_order);
    }

    const catsCfg = settings.categories || {};
    const keys = Object.keys(catsCfg);
    if (keys.length) {
      return keys.map((key, i) => {
        const c = catsCfg[key];
        let enabled = true;
        let label = key;
        if (typeof c === 'boolean') enabled = c;
        else if (c && typeof c === 'object') {
          enabled = c.enabled !== false;
          label = c.label_tr || c.label || key;
        }
        return { id: key, label, enabled, sort_order: i };
      });
    }
    return DEFAULT_NAV.map((c) => ({ ...c }));
  }

  function productNavKey(p) {
    const nav = (p.qr_nav_category_id || '').trim();
    if (nav) return nav;
    const cat = p.category || 'tost';
    if (cat === 'combo') return 'drink';
    return cat;
  }

  function render(settings, products, extras) {
    const order = settings.product_display_order || [];
    const orderMap = new Map(order.map((id, i) => [id, i]));
    const featuredIds = settings.featured_product_ids || [];
    const navCats = resolveNavCategories(settings);

    const sections = [];

    function sortItems(items) {
      return items.sort((a, b) => {
        const ai = orderMap.has(a.id) ? orderMap.get(a.id) : 9999;
        const bi = orderMap.has(b.id) ? orderMap.get(b.id) : 9999;
        if (ai !== bi) return ai - bi;
        return productTitle(a).localeCompare(productTitle(b), 'tr');
      });
    }

    function pushSection(key, title, items) {
      sections.push({ key, title, items: sortItems([...items]) });
    }

    const byNav = {};
    allItemsById = new Map();

    for (const p of products) {
      if (p.is_available === false) continue;
      if (isHidden(p.id, settings)) continue;
      allItemsById.set(p.id, p);
      const key = productNavKey(p);
      if (!byNav[key]) byNav[key] = [];
      byNav[key].push(p);
    }

    const extraNav = navCats.find((c) => c.id === 'extra' && c.enabled);
    if (extraNav) {
      const extraItems = (extras || [])
        .filter((e) => !isHidden(e.id, settings))
        .map((e) => {
          const item = {
            id: e.id,
            name: e.name,
            description: e.description || '',
            price: e.price,
            image_url: e.image_url,
          };
          allItemsById.set(e.id, item);
          return item;
        });
      if (!byNav.extra) byNav.extra = [];
      byNav.extra.push(...extraItems);
    }

    for (const cat of navCats) {
      if (!cat.enabled) continue;
      pushSection(cat.id, cat.label, byNav[cat.id] || []);
    }

    // Navbar'da olmayan ama ürünü olan özel kategoriler
    for (const key of Object.keys(byNav)) {
      if (sections.some((s) => s.key === key)) continue;
      if (!(byNav[key] || []).length) continue;
      pushSection(key, key, byNav[key]);
    }

    sectionsCache = sections;
    els.brandTitle.textContent = settings.title || 'Tost-u Şahane';
    els.garsonWrap.hidden = tableNumber <= 0;

    if (tableNumber > 0) {
      els.tableChip.hidden = false;
      els.tableChip.textContent = `Masa ${tableNumber}`;
    } else {
      els.tableChip.hidden = true;
    }

    els.loading.hidden = true;

    if (!sections.length) {
      els.homeBody.hidden = true;
      els.loading.hidden = false;
      els.loading.className = 'empty';
      els.loading.textContent = 'Menü henüz hazır değil.';
      return;
    }

    els.homeBody.hidden = false;

    // Öne çıkanlar — yönetici seçimi
    const featured = [];
    for (const id of featuredIds) {
      const item = allItemsById.get(id);
      if (!item) continue;
      if (isHidden(id, settings)) continue;
      featured.push(item);
    }

    if (featured.length) {
      els.featuredSection.hidden = false;
      els.featuredCarousel.innerHTML = featured
        .map((item, i) => {
          const src = thumbSrc(item.image_url);
          return `<button type="button" class="yml-box" data-fi="${i}">
            <div class="yml-img">${mediaHtml(src)}</div>
            <div class="yml-food-text">${escapeHtml(productTitle(item))}</div>
            <div class="yml-price">${priceParts(item.price).formatted} TL</div>
          </button>`;
        })
        .join('');
      els.featuredCarousel.querySelectorAll('.yml-box').forEach((btn) => {
        btn.addEventListener('click', () => {
          const item = featured[Number(btn.dataset.fi)];
          if (!item) return;
          const section =
            sectionsCache.find((s) => s.items.some((x) => x.id === item.id)) ||
            null;
          openDetail(item, section);
        });
      });
    } else {
      els.featuredSection.hidden = true;
      els.featuredCarousel.innerHTML = '';
    }

    // Kategori navbar
    els.catNav.innerHTML = sections
      .map(
        (s) =>
          `<button type="button" class="cat-nav-btn" data-key="${s.key}">${escapeHtml(s.title)}</button>`,
      )
      .join('');
    els.catNav.querySelectorAll('.cat-nav-btn').forEach((btn) => {
      btn.addEventListener('click', () => selectCategory(btn.dataset.key, true));
    });

    // Varsayılan: Tostlar (yoksa ilk kategori)
    const defaultKey = sections.some((s) => s.key === 'tost')
      ? 'tost'
      : sections[0].key;
    selectCategory(defaultKey, false);
  }

  async function callWaiter() {
    if (!tableNumber) {
      showToast('Masa numarası yok. QR kodunu masadan okutun.');
      return;
    }
    els.btnCall.disabled = true;
    try {
      const res = await fetch(cfg.requestUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          branchId,
          tableNumber,
          type: 'call_waiter',
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || 'request_failed');
      showToast(`Garson çağrıldı · Masa ${tableNumber}`);
    } catch (e) {
      console.error(e);
      showToast('Gönderilemedi. Biraz sonra tekrar deneyin.');
    } finally {
      setTimeout(() => {
        els.btnCall.disabled = false;
      }, 2500);
    }
  }

  async function boot() {
    try {
      const { settings, products, extras } = await loadMenu();
      const safeSettings = {
        title: 'Tost-u Şahane',
        welcome_note: 'Lezzetler sofranıza gelsin.',
        categories: {},
        enabled: true,
        hidden_product_ids: [],
        featured_product_ids: [],
        product_display_order: [],
        ...settings,
      };
      if (safeSettings.enabled === false) {
        els.loading.className = 'empty';
        els.loading.textContent = 'QR menü şu an kapalı.';
        els.garsonWrap.hidden = true;
        return;
      }
      render(safeSettings, products || [], extras || []);
    } catch (e) {
      console.error(e);
      els.loading.hidden = false;
      els.loading.className = 'empty';
      els.loading.textContent =
        'Menü yüklenemedi. Sayfayı yenileyin veya internetinizi kontrol edin.';
      if (els.homeBody) els.homeBody.hidden = true;
    }
  }

  els.btnHome.addEventListener('click', showHome);
  els.btnDetailBack.addEventListener('click', (e) => {
    e.preventDefault();
    showHome();
  });
  els.btnCall.addEventListener('click', callWaiter);
  boot();
})();
