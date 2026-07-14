// QuantLab dashboard — vanilla JS + Firebase Auth (Google) + Gemini
// (Gemini Developer API direto, free tier, chave restrita por domínio).
import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.4.0/firebase-app.js';
import {
  getAuth, GoogleAuthProvider, signInWithPopup, signInWithRedirect,
  getRedirectResult, onAuthStateChanged, signOut,
} from 'https://www.gstatic.com/firebasejs/12.4.0/firebase-auth.js';
import {
  getFirestore, doc, getDoc,
} from 'https://www.gstatic.com/firebasejs/12.4.0/firebase-firestore.js';

const app = initializeApp({
  projectId: 'quantlab-lde',
  appId: '1:1025412444243:web:e1fcf413f6144e524a96a6',
  apiKey: 'AIzaSyA1EcBYGb5sdH9KEqfmDFaWQrUQGSyO7fk',
  authDomain: 'quantlab-lde.firebaseapp.com',
});
const auth = getAuth(app);
const db = getFirestore(app);

const $ = (id) => document.getElementById(id);
const els = {
  login: $('btn-login'), loginHero: $('btn-login-hero'), heroHint: $('hero-hint'),
  userChip: $('user-chip'), userPhoto: $('user-photo'), userName: $('user-name'),
  logout: $('btn-logout'), dash: $('dash'), hero: $('hero'),
  macro: $('macro-strip'), resumo: $('resumo'), ranking: $('ranking'),
  cards: $('cards'), hipoteses: $('hipoteses'),
  tabs: $('tabs'), filters: $('filters'), updated: $('updated-at'),
  toast: $('toast'),
};

// ── formatação pt-BR ──────────────────────────────────────────────────
const nf = new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 2 });
const fmtNum = (v, d = 2) => v == null ? '—'
  : new Intl.NumberFormat('pt-BR', { minimumFractionDigits: d, maximumFractionDigits: d }).format(v);
const fmtPct = (v, d = 1, sign = true) => v == null ? '—'
  : `${sign && v > 0 ? '+' : ''}${new Intl.NumberFormat('pt-BR',
      { minimumFractionDigits: d, maximumFractionDigits: d }).format(v * 100)}%`;
const fmtData = (iso) => iso ? iso.split('-').reverse().join('/') : '';
const esc = (s) => String(s).replace(/[&<>"']/g,
  (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function toast(msg, ms = 6000) {
  els.toast.textContent = msg;
  els.toast.classList.remove('hidden');
  clearTimeout(toast._t);
  toast._t = setTimeout(() => els.toast.classList.add('hidden'), ms);
}

// ── ícones temáticos (SVG inline, sem emoji) ──────────────────────────
const ICONS = {
  shield: '<path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z"/>',
  scales: '<path d="M12 4v16M8 20h8M4 8h16"/><path d="M7 8l-3 5a3 3 0 0 0 6 0zM17 8l-3 5a3 3 0 0 0 6 0z"/>',
  bolt: '<path d="M13 2L5 13h5l-1 9 8-11h-5z"/>',
  target: '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/>',
  bank: '<path d="M3 9.5l9-5.5 9 5.5M5 10v7M9.5 10v7M14.5 10v7M19 10v7M3 19.5h18"/>',
  alert: '<path d="M12 4.5l8.5 15h-17z"/><path d="M12 10v4M12 17.2v.3"/>',
  stop: '<circle cx="12" cy="12" r="8.5"/><path d="M9 9l6 6M15 9l-6 6"/>',
  check: '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 12.5l2.5 2.5 4.5-5.5"/>',
  flag: '<path d="M6 21V4h11.5l-2.2 4 2.2 4H6"/>',
  up: '<path d="M4 17l5.5-5.5 3.5 3L19 8"/><path d="M13.5 8H19v5.5"/>',
  down: '<path d="M4 8l5.5 5.5 3.5-3L19 17"/><path d="M13.5 17H19v-5.5"/>',
  chart: '<path d="M4 20V4M4 20h16"/><path d="M8.5 16v-5M12.5 16V8M16.5 16v-3"/>',
  chevron: '<path d="M9 6.5l5.5 5.5L9 17.5"/>',
  book: '<path d="M5 5a2 2 0 0 1 2-2h12v16H7a2 2 0 0 0-2 2z"/><path d="M5 19a2 2 0 0 1 2-2h12"/>',
};
const icon = (n, cls = '') =>
  `<svg class="ic ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"
    aria-hidden="true">${ICONS[n] || ''}</svg>`;

// ── auth ──────────────────────────────────────────────────────────────
async function login() {
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    if (e.code === 'auth/popup-blocked' || e.code === 'auth/internal-error' ||
        e.code === 'auth/operation-not-supported-in-this-environment') {
      // popup bloqueado (comum no mobile/PWA) → tenta o fluxo por redirect
      try {
        await signInWithRedirect(auth, new GoogleAuthProvider());
      } catch (e2) {
        toast('Falha no login: ' + (e2.code || e2.message));
      }
    } else if (e.code === 'auth/operation-not-allowed' || e.code === 'auth/configuration-not-found') {
      toast('Login Google ainda não está ativado no console do Firebase ' +
            '(Authentication → Sign-in method → Google).', 9000);
    } else if (e.code === 'auth/unauthorized-domain') {
      toast('Este domínio não está autorizado no Firebase Auth.', 9000);
    } else if (e.code !== 'auth/popup-closed-by-user' && e.code !== 'auth/cancelled-popup-request') {
      toast('Falha no login: ' + (e.code || e.message));
    }
  }
}
getRedirectResult(auth).catch((e) => {
  if (e.code !== 'auth/no-auth-event') toast('Falha no login: ' + (e.code || e.message));
});
els.login.onclick = login;
els.loginHero.onclick = login;
els.logout.onclick = () => signOut(auth);

onAuthStateChanged(auth, (user) => {
  const logged = !!user;
  els.login.classList.toggle('hidden', logged);
  els.loginHero.classList.toggle('hidden', logged);
  els.heroHint.classList.toggle('hidden', logged);
  els.userChip.classList.toggle('hidden', !logged);
  els.dash.classList.toggle('hidden', !logged);
  els.hero.classList.toggle('hidden', logged);
  $('fab-oraculo').classList.toggle('hidden', !logged);
  if (logged) {
    els.userPhoto.src = user.photoURL || '';
    els.userName.textContent = (user.displayName || user.email || '').split(' ')[0];
    loadData();
    carregarPortfolioEtoro();
  }
});

// ── portfólio real do eToro (privado, lido do Firestore) ──────────────
let etoroPortfolio = null; // { atualizadoEm, posicoes:[...] }
async function carregarPortfolioEtoro() {
  try {
    const snap = await getDoc(doc(db, 'private', 'portfolio'));
    etoroPortfolio = snap.exists() ? snap.data() : null;
  } catch (_) {
    etoroPortfolio = null; // sem permissão (outro usuário) ou offline
  }
  if (DATA) { renderEtoroPortfolio(); }
}

// ── dados ─────────────────────────────────────────────────────────────
let DATA = null;
let horizonte = 'curto';
let filtro = 'todos';

async function loadData() {
  if (DATA) return;
  try {
    const r = await fetch('/data/dashboard.json', { cache: 'no-cache' });
    DATA = await r.json();
  } catch {
    toast('Não consegui carregar os dados do painel.');
    return;
  }
  atualizarTopo();
  renderMacro();
  render();
  renderRadar();
  renderHipoteses();
  preencherFormAtivos();
  renderPosicoes();
  sincronizarOraculo(false);
  if (location.hash.startsWith('#a=')) openModal(location.hash.slice(3));
}

function atualizarTopo() {
  const hora = DATA.geradoEm
    ? new Date(DATA.geradoEm).toLocaleTimeString('pt-BR',
        { hour: '2-digit', minute: '2-digit' })
    : '';
  els.updated.textContent =
    `dados até ${fmtData(DATA.ultimaObservacao)} · ` +
    `gerado ${fmtData(DATA.geradoEm?.slice(0, 10))} ${hora}`;
}

// auto-refresh: o pipeline roda na nuvem a cada 2h — o painel se
// atualiza sozinho quando sai versão nova (verifica a cada 5 min)
setInterval(async () => {
  if (!DATA) return;
  // portfólio real do eToro (P&L acompanha as atualizações do pipeline)
  carregarPortfolioEtoro();
  try {
    const r = await fetch('/data/dashboard.json', { cache: 'no-cache' });
    const novo = await r.json();
    if (novo.geradoEm && novo.geradoEm !== DATA.geradoEm) {
      DATA = novo;
      renderMacro();
      render();
      renderRadar();
      renderHipoteses();
      renderPosicoes();
      sincronizarOraculo();
      atualizarTopo();
      toast('Dados atualizados automaticamente.');
    }
  } catch { /* offline/transiente: tenta de novo no próximo ciclo */ }
}, 5 * 60 * 1000);

// ── macro strip ───────────────────────────────────────────────────────
const dirTxt = { subindo: ['▲ subindo', 'up'], caindo: ['▼ caindo', 'down'], estavel: ['◆ estável', 'flat'] };
function renderMacro() {
  const m = DATA.macro;
  if (!m) return;
  const items = [
    ['Selic', `${fmtNum(m.selic)}%`, dirTxt[m.selicDirecao]],
    ['IPCA 12m', fmtPct(m.ipca12m, 1, false), dirTxt[m.inflacaoTendencia]],
    ['Juro real', `${fmtPct(m.juroReal, 1, false)} a.a.`, null],
    ['Dólar PTAX', `R$ ${fmtNum(m.dolar)}`, null],
    ['Treasury 10a', `${fmtNum(m.us10y)}%`, m.us10yDirecao ? dirTxt[m.us10yDirecao] : null],
    ['Dólar global', m.dxyForte == null ? '—' : (m.dxyForte ? 'forte' : 'fraco'),
      m.dxyForte == null ? null : (m.dxyForte ? ['DXY > SMA-200', 'down'] : ['DXY < SMA-200', 'up'])],
  ];
  els.macro.innerHTML = items.map(([lbl, val, dir]) => `
    <div class="mstat">
      <div class="lbl">${lbl}</div>
      <div class="val">${val}</div>
      ${dir ? `<div class="sub ${dir[1]}">${dir[0]}</div>` : '<div class="sub">&nbsp;</div>'}
    </div>`).join('');
}

// ── cards de oportunidade ─────────────────────────────────────────────
const badgeTxt = { compra: '▲ LONG · COMPRA', venda: '▼ SHORT · VENDA', neutro: '· NEUTRO' };
const effClass = (v) => v == null ? 'bad' : v >= 0.6 ? 'good' : v >= 0.45 ? 'mid' : 'bad';

function sparkSvg(o) {
  const raw = DATA.charts?.[o.id]?.v?.filter((x) => x != null);
  if (!raw || raw.length < 10) return '';
  const v = raw.slice(-52); // ~1 ano
  const min = Math.min(...v), max = Math.max(...v), span = max - min || 1;
  const W = 240, H = 44, P = 3;
  const pts = v.map((x, i) =>
    `${(P + i * (W - 2 * P) / (v.length - 1)).toFixed(1)},${(P + (H - 2 * P) * (1 - (x - min) / span)).toFixed(1)}`);
  const line = 'M' + pts.join('L');
  const up = v[v.length - 1] >= v[0];
  return `<svg class="spark" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" aria-hidden="true">
    <path class="area ${up ? 'aup' : 'adn'}" d="${line}L${W - P},${H}L${P},${H}Z"/>
    <path class="line ${up ? 'up' : 'dn'}" d="${line}"/></svg>`;
}

function cardHtml(o, i) {
  const dir = o.direcao;
  const neutro = dir === 'neutro';
  const score = neutro ? 0 : o.score;
  const C = 2 * Math.PI * 32;

  // card minimalista — o dossiê completo mora no Raio-X (modal)
  return `
  <div class="card ${neutro ? 'neutro' : ''}" data-dir="${dir}" data-id="${esc(o.id)}" style="transition-delay:${Math.min(i * 45, 400)}ms">
    <div class="card-top">
      <div>
        <h3>${esc(o.nome)}</h3>
        <div class="cat">${esc(o.categoria)} · ${fmtNum(o.preco)}</div>
      </div>
      <span class="badge ${dir}">${badgeTxt[dir]}</span>
    </div>
    <div class="card-mid">
      <div class="ring ${dir}">
        <svg width="64" height="64" viewBox="0 0 74 74">
          <circle class="track" r="32" cx="37" cy="37" fill="none" stroke-width="7"/>
          <circle class="bar" r="32" cx="37" cy="37" fill="none" stroke-width="7"
            stroke-dasharray="${C}" stroke-dashoffset="${C}" data-off="${C * (1 - score / 100)}"/>
        </svg>
        <div class="num">${neutro ? '—' : Math.round(score)}<small>convicção</small></div>
      </div>
      <div class="card-spark">${sparkSvg(o)}</div>
    </div>
  </div>`;
}

function renderResumo() {
  const ops = DATA.horizontes[horizonte].oportunidades;
  const longs = ops.filter((o) => o.direcao === 'compra');
  const shorts = ops.filter((o) => o.direcao === 'venda');
  const topL = longs[0], topS = shorts[0];
  els.resumo.innerHTML = `
    <span><b>${DATA.horizontes[horizonte].label}</b>:</span>
    <span class="r-long">▲ ${longs.length} long</span><span class="dot">·</span>
    <span class="r-short">▼ ${shorts.length} short</span>
    ${topL ? `<span class="dot">·</span><span>destaque long: <b>${esc(topL.nome)}</b> (${Math.round(topL.score)})</span>` : ''}
    ${topS ? `<span class="dot">·</span><span>destaque short: <b>${esc(topS.nome)}</b> (${Math.round(topS.score)})</span>` : ''}`;
}

// ── ranking acionável + dimensionamento de posição ───────────────────
// A política de alocação (cortes, risco por trade, tetos, alavancagem)
// vive no DOMÍNIO (quant_engine/PortfolioSizer) e chega pronta no JSON
// como `carteiras` — este cliente não conhece a regra.
let capital = +(localStorage.getItem('ql_capital') || 0);
let soEtoro = true; // uso pessoal: só o que dá para executar na conta
let riscoSel = 'moderado'; // perfil GLOBAL: sizing, ranking e Oráculo

// ── controles unificados (perfil, filtros, capital) ───────────────────
$('seg-risco').innerHTML = [
  ['conservador', 'shield', 'Conservador'],
  ['moderado', 'scales', 'Moderado'],
  ['agressivo', 'bolt', 'Agressivo'],
].map(([v, ic, l]) =>
  `<button data-v="${v}" class="${v === riscoSel ? 'active' : ''}">${icon(ic)}<span class="seg-lbl">${l}</span></button>`).join('');
$('seg-risco').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-v]');
  if (!b) return;
  riscoSel = b.dataset.v;
  $('seg-risco').querySelectorAll('button')
    .forEach((x) => x.classList.toggle('active', x === b));
  if (DATA) { renderRanking(); sincronizarOraculo(); }
});

els.filters.innerHTML = `
  <button class="chip active" data-f="todos">Todos</button>
  <button class="chip chip-long" data-f="compra">▲ LONG</button>
  <button class="chip chip-short" data-f="venda">▼ SHORT</button>
  <button class="chip" data-f="neutro">Neutros</button>
  <button class="chip chip-etoro active" id="chip-etoro"
    title="Somente ativos com instrumento no eToro">${icon('target')} eToro</button>`;
$('chip-etoro').addEventListener('click', () => {
  soEtoro = !soEtoro;
  $('chip-etoro').classList.toggle('active', soEtoro);
  if (DATA) { renderRanking(); sincronizarOraculo(); }
});

const capInput = $('inp-capital');
if (capital > 0) capInput.value = capital;
capInput.addEventListener('input', () => {
  capital = +capInput.value || 0;
  localStorage.setItem('ql_capital', String(capital));
  if (DATA) { renderRanking(); sincronizarOraculo(); }
});

/// A carteira vem PRONTA do domínio (PortfolioSizer, no pipeline) — aqui
/// só se converte peso→R$ e níveis de preço para exibição. Nenhuma regra
/// de alocação vive no cliente (DDD: fonte única no quant_engine).
function calcularOrdens(hKey) {
  const h = DATA.horizontes[hKey];
  const cart = h.carteiras?.[riscoSel]?.[soEtoro ? 'etoro' : 'todos'];
  const porId = {};
  for (const o of h.oportunidades) porId[o.id] = o;
  if (!cart) {
    return { linhas: [], caixaPct: 1, segurados: [], foraEtoro: [], cortePct: 55 };
  }

  const linhas = (cart.ordens || []).map((w) => {
    const o = porId[w.id];
    if (!o) return null;
    const r = o.recomendacao;
    const stop = r.stopEstimado || 0.05;
    const compra = r.acao === 'comprar';
    const lev = w.alavancagem || 1;
    const exposicao = capital > 0 ? capital * w.peso : null;
    return {
      o,
      peso: w.peso,
      lev,
      valor: exposicao,
      margem: exposicao == null ? null : exposicao / lev,
      stopPreco: o.preco != null
        ? o.preco * (compra ? 1 - stop : 1 + stop) : null,
      alvoPreco: o.preco != null && r.retornoEsperado != null
        ? o.preco * (compra ? 1 + r.retornoEsperado : 1 - r.retornoEsperado)
        : null,
    };
  }).filter(Boolean);

  return {
    linhas,
    caixaPct: cart.caixaPct ?? 1,
    segurados: (cart.segurados || []).map((id) => porId[id]).filter(Boolean),
    foraEtoro: (cart.foraEtoro || []).map((id) => porId[id]).filter(Boolean),
    cortePct: cart.cortePct ?? 55,
  };
}

function renderRanking() {
  const { linhas, caixaPct, segurados, foraEtoro, cortePct } =
    calcularOrdens(horizonte);
  const ordens = linhas.map((l) => l.o);

  let html = `<h2 class="rank-title">O que fazer agora —
    ${DATA.horizontes[horizonte].label.toLowerCase()} · perfil ${riscoSel}</h2>`;
  if (!ordens.length) {
    html += `<div class="rank-empty">Nenhuma ordem passa no corte de
      assertividade do perfil ${riscoSel} (${cortePct}%)
      neste horizonte — o laboratório prefere ficar de fora a chutar.</div>`;
  } else {
    html += linhas.map((l, i) => {
      const o = l.o;
      const r = o.recomendacao;
      const tk = o.etoro?.ticker;
      const peso = l.peso;
      const valor = l.valor;
      const riscoRs = valor != null ? valor * (r.stopEstimado || 0.05) : null;
      const nivel = (x) => x == null ? '' : fmtNum(x, x >= 100 ? 0 : 2);
      const sl = l.stopPreco != null && l.alvoPreco != null
        ? ` · SL ~<b>${nivel(l.stopPreco)}</b> · alvo ~<b>${nivel(l.alvoPreco)}</b>`
        : '';
      const sizing = (valor != null
        ? (l.lev > 1
            ? `Invista <b>R$ ${fmtNum(l.margem, 0)}</b> com alavancagem
               <b>X${l.lev}</b> (exposição R$ ${fmtNum(valor, 0)} ·
               ${fmtPct(peso, 1, false)}) · risco ≈ R$ ${fmtNum(riscoRs, 0)}`
            : `Posição sugerida: <b>R$ ${fmtNum(valor, 0)}</b>
               (${fmtPct(peso, 1, false)}) · X1
               · risco até o stop ≈ R$ ${fmtNum(riscoRs, 0)}`)
        : `Peso sugerido: <b>${fmtPct(peso, 1, false)}</b> do capital
           (informe o capital acima para ver em R$)`) + sl;
      const kv = (k, v) =>
        `<div class="kv"><div class="k">${k}</div><div class="v">${v}</div></div>`;
      return `<details class="rank-row" data-id="${esc(o.id)}">
        <summary>
          <span class="rank-pos">${i + 1}</span>
          <span class="badge ${o.direcao}">${r.acao === 'comprar' ? '▲ COMPRAR' : '▼ VENDER'}</span>
          <span class="row-name">${esc(o.nome)}${tk ? `<span class="tick">${esc(tk)}</span>` : ''}</span>
          <span class="row-ass"><b>${fmtPct(r.assertividade, 0, false)}</b><small>assertividade</small></span>
          <span class="chev">${icon('chevron')}</span>
        </summary>
        <div class="row-body">
          <div class="kv-grid kv-mini">
            ${kv('Retorno esp. (' + r.janelaRetorno + ')', fmtPct(r.retornoEsperado))}
            ${kv('Base histórica', 'n=' + r.base)}
            ${kv('Stop estimado', r.stopEstimado ? fmtPct(r.stopEstimado, 0, false) : '—')}
            ${kv('Alavancagem', 'X' + l.lev)}
            ${kv('Convicção', Math.round(o.score) + '/100')}
          </div>
          <p class="row-sizing">${sizing}</p>
          <p class="row-gat">${icon('flag')} ${esc(r.gatilho || '')}${o.etoro?.nota ? ` · <i>${esc(o.etoro.nota)}</i>` : ''}</p>
          <div class="row-actions">
            <button class="btn-exec" data-exec="${esc(o.id)}">Executei no eToro</button>
            <button class="btn-raiox" data-modal="${esc(o.id)}">${icon('chart')} Raio-X completo</button>
          </div>
        </div>
      </details>`;
    }).join('');
    html += `<div class="rank-caixa">${icon('bank')} Caixa/renda fixa:
      <b>${fmtPct(caixaPct, 0, false)}</b>
      ${capital > 0 ? `(R$ ${fmtNum(capital * caixaPct, 0)})` : ''} —
      com juro real de ${fmtPct(DATA.macro?.juroReal, 1, false)} a.a., caixa
      também é posição.</div>`;
  }
  if (foraEtoro.length) {
    html += `<div class="rank-fora">Aprovados mas sem instrumento no eToro
      (desative o filtro eToro para ver):
      ${foraEtoro.map((o) => esc(o.nome)).join(', ')}.</div>`;
  }
  if (segurados.length) {
    html += `<div class="rank-fora">Sinal presente mas abaixo do corte de
      ${cortePct}% do perfil: ${segurados.map((o) => esc(o.nome)).join(', ')} — ficar de fora.</div>`;
  }
  els.ranking.innerHTML = html;
}

els.ranking?.addEventListener('click', (e) => {
  const exec = e.target.closest('[data-exec]');
  if (exec) {
    registrarExecucao(exec.dataset.exec);
    return;
  }
  const raiox = e.target.closest('[data-modal]');
  if (raiox) openModal(raiox.dataset.modal);
});

function render() {
  renderResumo();
  renderRanking();
  const ops = DATA.horizontes[horizonte].oportunidades
    .filter((o) => filtro === 'todos' ? true : o.direcao === filtro)
    .sort((a, b) => (b.direcao !== 'neutro') - (a.direcao !== 'neutro') || b.score - a.score);
  els.cards.innerHTML = ops.length
    ? ops.map(cardHtml).join('')
    : '<p style="color:var(--dimmer);padding:30px 6px">Nenhum ativo neste filtro.</p>';
  requestAnimationFrame(() => requestAnimationFrame(() => {
    els.cards.querySelectorAll('.card').forEach((c) => c.classList.add('vis'));
    els.cards.querySelectorAll('.bar').forEach((b) => { b.style.strokeDashoffset = b.dataset.off; });
  }));
}

els.tabs.addEventListener('click', (e) => {
  const t = e.target.closest('.tab');
  if (!t) return;
  horizonte = t.dataset.h;
  els.tabs.querySelectorAll('.tab').forEach((x) => x.classList.toggle('active', x === t));
  render();
  sincronizarOraculo();
});
els.filters.addEventListener('click', (e) => {
  const c = e.target.closest('.chip');
  if (!c || !c.dataset.f) return; // chips sem data-f têm handler próprio
  filtro = c.dataset.f;
  els.filters.querySelectorAll('.chip[data-f]')
    .forEach((x) => x.classList.toggle('active', x === c));
  render();
});

// ── hipóteses ─────────────────────────────────────────────────────────
function renderHipoteses() {
  const hs = DATA.hipoteses || [];
  els.hipoteses.innerHTML = hs.length ? hs.map((h) => `
    <div class="hip">
      <div class="rel">${esc(h.causa)} <b>→</b> ${esc(h.efeito)}</div>
      <span class="m">lag ${h.lagMeses}m</span>
      <span class="m">ρ treino ${fmtNum(h.rhoTreino)}</span>
      <span class="m">ρ teste ${fmtNum(h.rhoTeste)}</span>
      <span class="st ${h.status}">${h.status}</span>
    </div>`).join('')
    : '<p style="color:var(--dimmer)">Nenhuma hipótese publicada ainda.</p>';
}

// ── modal raio-X do ativo ─────────────────────────────────────────────
const modalEl = $('modal');
const modalBody = $('modal-body');

function closeModal() {
  modalEl.classList.add('hidden');
  if (location.hash.startsWith('#a=')) {
    history.replaceState(null, '', location.pathname);
  }
}
$('modal-close').onclick = closeModal;
$('modal-back').onclick = closeModal;
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') closeModal();
});

function bigChartSvg(o) {
  const c = DATA.charts?.[o.id];
  if (!c?.v?.length) return '';
  const v = c.v, sm = c.s, ds = c.d;
  const all = v.concat(sm).filter((x) => x != null);
  if (all.length < 10) return '';
  const min = Math.min(...all), max = Math.max(...all), span = max - min || 1;
  const W = 700, H = 240, L = 8, R = 8, T = 12, B = 24;
  const X = (i) => (L + i * (W - L - R) / (v.length - 1)).toFixed(1);
  const Y = (x) => (T + (H - T - B) * (1 - (x - min) / span)).toFixed(1);
  const path = (arr) => arr.map((x, i) => x == null ? ''
    : `${i === 0 || arr[i - 1] == null ? 'M' : 'L'}${X(i)},${Y(x)}`).join('');
  const last = v.length - 1;
  return `<svg class="bigchart" viewBox="0 0 ${W} ${H}">
      <path class="smaln" d="${path(sm)}"/>
      <path class="price" d="${path(v)}"/>
      ${v[last] == null ? '' : `<circle cx="${X(last)}" cy="${Y(v[last])}" r="4" fill="#4f9cff"/>`}
      <text class="axis" x="${L}" y="${H - 8}">${fmtData(ds[0])}</text>
      <text class="axis" x="${W - R}" y="${H - 8}" text-anchor="end">${fmtData(ds[ds.length - 1])}</text>
      <text class="axis" x="${W - R}" y="${T + 8}" text-anchor="end">${fmtNum(max)}</text>
    </svg>
    <div class="chart-leg"><span class="l1">preço (~3 anos, semanal)</span><span class="l2">SMA-200</span></div>`;
}

function openModal(id) {
  const o = DATA?.horizontes[horizonte].oportunidades.find((x) => x.id === id);
  if (!o) return;
  const s = o.sinais || {};
  const e = o.estrategia;
  const c3 = o.cenarios?.fwd3m, c12 = o.cenarios?.fwd12m;
  const kv = (k, v) => `<div class="kv"><div class="k">${k}</div><div class="v">${v}</div></div>`;
  modalBody.innerHTML = `
    <div class="m-head"><h3>${esc(o.nome)}</h3>
      <span class="badge ${o.direcao}">${badgeTxt[o.direcao]}</span></div>
    <div class="m-sub">${esc(o.categoria)} · ${esc(o.unidade)} ·
      ${fmtNum(o.preco)} em ${fmtData(o.dataPreco)} · convicção
      ${o.direcao === 'neutro' ? '—' : Math.round(o.score) + '/100'}
      (${DATA.horizontes[horizonte].label.toLowerCase()})</div>
    ${bigChartSvg(o)}
    ${e ? `<div class="m-sec">Backtest — ${esc(e.nome)}</div><div class="kv-grid">
      ${kv('Eficácia', e.winRate == null ? 'n/d' : fmtPct(e.winRate, 0, false))}
      ${kv('Trades', e.trades ?? '—')}
      ${kv('CAGR estratégia', fmtPct(e.cagr))}
      ${kv('CAGR buy & hold', fmtPct(e.cagrBuyHold))}
      ${kv('Sharpe OOS', fmtNum(e.sharpeOos))}
      ${kv('Walk-forward', e.walkForward || '—')}</div>` : ''}
    ${o.cenarios ? `<div class="m-sec">Cenários análogos —
        ${o.cenarios.n} episódios desde ${fmtData(o.cenarios.desde)}</div>
      <div class="kv-grid">
      ${c3 ? kv('3m · mediana', fmtPct(c3.mediana)) +
             kv('3m · a favor', fmtPct(c3.pctFavoravel, 0, false)) +
             kv('3m · Q1…Q3', `${fmtPct(c3.q1)} … ${fmtPct(c3.q3)}`) +
             kv('3m · pior/melhor', `${fmtPct(c3.pior)} / ${fmtPct(c3.melhor)}`) : ''}
      ${c12 ? kv('12m · mediana', fmtPct(c12.mediana)) +
              kv('12m · a favor', fmtPct(c12.pctFavoravel, 0, false)) +
              kv('12m · Q1…Q3', `${fmtPct(c12.q1)} … ${fmtPct(c12.q3)}`) +
              kv('12m · pior/melhor', `${fmtPct(c12.pior)} / ${fmtPct(c12.melhor)}`) : ''}
      </div>` : ''}
    ${o.alavancagem ? `<div class="m-sec">Alavancagem máxima sugerida</div><div class="kv-grid">
      ${kv('Sugerida', '≤ ' + fmtNum(o.alavancagem.sugerida) + 'x')}
      ${kv('Meio-Kelly', fmtNum(o.alavancagem.kellyMeio) + 'x')}
      ${kv('Teto por volatilidade', fmtNum(o.alavancagem.tetoVol) + 'x')}</div>` : ''}
    <div class="m-sec">Sinais</div><div class="kv-grid">
      ${kv('Retorno 1m', fmtPct(s.ret1m))}${kv('Retorno 3m', fmtPct(s.ret3m))}
      ${kv('Retorno 12m', fmtPct(s.ret12m))}${kv('Momentum 12-1', fmtPct(s.mom12x1))}
      ${kv('vs SMA-200', fmtPct(s.distSma200))}${kv('Z-score 60d', fmtNum(s.z60))}
      ${kv('Vol 1a', fmtPct(s.vol1y, 0, false))}${kv('Do topo', fmtPct(s.ddTopo))}</div>
    ${o.evidencias?.length ? `<div class="m-sec">Evidências</div>
      <ul class="m-evid">${o.evidencias.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>` : ''}
    <div class="row-actions" style="margin-top:18px">
      <button class="btn-raiox" data-mentor data-nome="${esc(o.nome)}">
        Orientação do Oráculo sobre este ativo</button>
    </div>`;
  modalEl.classList.remove('hidden');
  history.replaceState(null, '', '#a=' + id);
}

els.cards.addEventListener('click', (e) => {
  if (e.target.closest('details')) return;
  const card = e.target.closest('.card[data-id]');
  if (card) openModal(card.dataset.id);
});

// ── consultor IA (Gemini Developer API, free tier) ───────────────────
// Chave PÚBLICA por design (como a apiKey do Firebase): restrita ao
// serviço generativelanguage e aos domínios do QuantLab. Sem billing no
// projeto, o teto é o free tier — custo máximo: zero.
const GEMINI_KEY = 'AIzaSyAjI74u44OYqLOYfaVDs4bmtuWy-P-TIB0';
const GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta/'
  + 'models/gemini-2.5-flash:generateContent?key=' + GEMINI_KEY;
const AI_SYSTEM =
  'Você é o ORÁCULO, o operador-chefe do QuantLab dando instruções de ' +
  'EXECUÇÃO no eToro. Responda em português do Brasil, markdown enxuto, ' +
  'tom IMPERATIVO e específico, nestas seções: ' +
  '## Plano de execução — hoje: passo a passo numerado, UMA ordem por ' +
  'passo: "Abra o eToro e busque {TICKER} → toque em COMPRAR (ou ' +
  'VENDER) → valor R$ {valorRs} → alavancagem {alavancagem} → ' +
  'Stop Loss em {stopLossPreco} → Take Profit em {takeProfitPreco} → ' +
  'confirme." Use exatamente os valores fornecidos (valorRs já é a ' +
  'MARGEM a digitar; se a alavancagem for X2+, mencione a exposição ' +
  'exposicaoRs). Cruze com o radarDePico quando existir: se a ordem ' +
  'concordar com o radar, reforce; se o radar apontar contra a ordem, ' +
  'diga para reduzir o tamanho ou aguardar. ' +
  '## Depois de executar: rotina de acompanhamento (1x por dia, após a ' +
  'atualização do painel) e o gatilho de saída de cada posição. ' +
  '## Plano B — se o mercado virar: o que fazer se um stop for atingido ' +
  '(aceitar a perda planejada, NUNCA dobrar a aposta) e o que faria o ' +
  'plano mudar. ' +
  'REGRAS INEGOCIÁVEIS: use SOMENTE os números fornecidos (nunca invente ' +
  'preços, horários ou notícias). Se takeProfitPreco vier null, escreva ' +
  '"sem Take Profit — saia pelo gatilho" naquele passo (jamais escreva ' +
  '"null"). TIMING honesto: os sinais são de ' +
  'fechamento DIÁRIO — instrua a executar hoje, dentro do horário do ' +
  'mercado de cada ativo (cripto: 24h/7d; índices e ações: pregão da ' +
  'bolsa local; FX e futuros: ~24h em dias úteis), sem prometer timing ' +
  'intradiário. Se o usuário sugerir day trade ou "lucro diário", ' +
  'explique em 1 frase que os sinais do laboratório são de ciclo diário ' +
  '(fechamento) e não sustentam promessas intradiárias — a rotina ' +
  'rentável honesta é a revisão diária. Reserve o percentual de caixa ' +
  'informado e cite o juro real. Percentuais arredondados (77%, nunca ' +
  '0.7657) e R$ no padrão brasileiro. Termine com UMA linha de aviso de ' +
  'risco. ~350 palavras.';

const ORACULO_POS_SYSTEM =
  'Você é o ORÁCULO do QuantLab acompanhando posições ABERTAS do usuário ' +
  'no eToro. Para CADA posição, dê o veredito em negrito — MANTER, ' +
  'FECHAR AGORA ou AJUSTAR STOP (com o novo preço) — seguido de UMA linha ' +
  'de motivo baseada apenas nos dados fornecidos (status do painel, ' +
  'sinal atual, P&L, stop/alvo). Depois, uma linha de resumo do risco ' +
  'total. Não invente números nem notícias; as cotações são do ' +
  'fechamento diário informado. Português do Brasil, markdown com lista, ' +
  '~200 palavras, termine com uma linha de aviso de risco.';

// riscoSel é global (controles unificados); o Oráculo segue o horizonte
// ativo das abas — uma única fonte de verdade para toda a plataforma.

async function chamarGemini(prompt, sys = AI_SYSTEM) {
  const r = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: sys }] },
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 2000,
        thinkingConfig: { thinkingBudget: 0 },
      },
    }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.error?.message || ('HTTP ' + r.status));
  const t = (j.candidates?.[0]?.content?.parts || [])
    .map((p) => p.text || '').join('');
  if (!t) throw new Error('resposta vazia do modelo');
  return t;
}

const regrasPerfil = {
  conservador:
    'PERFIL CONSERVADOR: recomende apenas ordens do ranking com ' +
    'assertividade ≥ 0,65; zero alavancagem; máximo 15% por ativo; todo ' +
    'o resto em caixa/renda fixa (o juro real está nos dados).',
  moderado:
    'PERFIL MODERADO: siga o ranking (assertividade ≥ 0,55); alavancagem ' +
    'exatamente a fornecida em cada ordem (no máximo X2, e só quando o ' +
    'laboratório recomendou); máximo 25% por ativo; mantenha reserva em ' +
    'caixa.',
  agressivo:
    'PERFIL AGRESSIVO: além do ranking, pode citar sinais segurados pelo ' +
    'corte de 55% como posições especulativas de no máximo 5% cada, ' +
    'deixando claro o risco; alavancagem exatamente a fornecida em cada ' +
    'ordem; máximo 35% por ativo.',
};

function aiPrompt() {
  const h = DATA.horizontes[horizonte];
  const plano = calcularOrdens(horizonte);
  const arred = (x, d = 2) => x == null ? null : +(+x).toFixed(d);
  // preços já formatados em pt-BR para a IA copiar sem mutilar
  const nivel = (x) => x == null ? null : fmtNum(x, x >= 100 ? 0 : 4);
  const ordens = plano.linhas.map((l) => ({
    nome: l.o.nome,
    tickerEtoro: l.o.etoro?.ticker ?? null,
    notaEtoro: l.o.etoro?.nota ?? null,
    acao: l.o.recomendacao.acao, // comprar | vender (short)
    categoria: l.o.categoria,
    valorRs: l.margem == null ? null : Math.round(l.margem),
    exposicaoRs: l.valor == null ? null : Math.round(l.valor),
    alavancagem: 'X' + l.lev,
    pesoPct: arred(l.peso * 100, 1),
    precoAtual: nivel(l.o.preco),
    stopLossPreco: nivel(l.stopPreco),
    takeProfitPreco: nivel(l.alvoPreco),
    assertividadePct: arred((l.o.recomendacao.assertividade || 0) * 100, 0),
    n: l.o.recomendacao.base,
    retornoEsperadoPct:
        arred((l.o.recomendacao.retornoEsperado || 0) * 100, 1),
    janela: l.o.recomendacao.janelaRetorno,
    gatilhoSaida: l.o.recomendacao.gatilho,
    radarDePico: l.o.radar
      ? { tipo: l.o.radar.tipo,
          probPct: Math.round((l.o.radar.prob || 0) * 100) }
      : null,
  }));
  const alertasRadar = (DATA.radarPicos || []).slice(0, 3).map((r) =>
    `${r.nome}: ${r.tipo.toUpperCase()} ${Math.round(r.prob * 100)}% (n=${r.n})`);
  return `${regrasPerfil[riscoSel]}
HORIZONTE PEDIDO: ${h.label} (${h.janela}).
CAPITAL DO USUÁRIO: ${capital > 0 ? 'R$ ' + capital : 'não informado (use % do capital)'}.
CAIXA/RENDA FIXA SUGERIDO: ${Math.round(plano.caixaPct * 100)}% do capital.
MACRO (dados oficiais): ${JSON.stringify(DATA.macro)}
ORDENS APROVADAS PELO LABORATÓRIO (já dimensionadas — monte o passo a
passo EXATAMENTE com estes valores): ${JSON.stringify(ordens)}
NÃO OPERAR (sinal fraco ou segurado): ${plano.segurados.map((o) => o.nome).join(', ') || 'nenhum'}.
ALERTAS DO RADAR DE PICOS (leitura técnica; probabilidade empírica de
virada em ~21 pregões): ${alertasRadar.join(' | ') || 'nenhum'}.
Monte o plano de execução agora.`;
}

function mdParaHtml(md) {
  const linhas = esc(md).split(/\r?\n/);
  let html = '';
  let emLista = false;
  for (const l of linhas) {
    const t = l.trim();
    if (t.startsWith('## ')) {
      if (emLista) { html += '</ul>'; emLista = false; }
      html += `<h3>${t.slice(3)}</h3>`;
    } else if (t.startsWith('- ') || t.startsWith('* ')) {
      if (!emLista) { html += '<ul>'; emLista = true; }
      html += `<li>${t.slice(2)}</li>`;
    } else if (t) {
      if (emLista) { html += '</ul>'; emLista = false; }
      html += `<p>${t}</p>`;
    }
  }
  if (emLista) html += '</ul>';
  return html.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
}

async function gerarIA() {
  if (!DATA) return;
  const out = $('ai-out');
  const btn = $('btn-ai');
  out.classList.remove('hidden');
  out.innerHTML = '<div class="ai-loading">O Oráculo está analisando '
    + 'os números do laboratório…</div>';
  btn.disabled = true;
  try {
    const texto = await chamarGemini(aiPrompt());
    out.innerHTML = mdParaHtml(texto) +
      `<div class="ai-meta">Oráculo (Gemini) — gerado a partir dos dados do
       painel · perfil ${riscoSel} · ${DATA.horizontes[horizonte].label.toLowerCase()}
       · não é recomendação de investimento</div>`;
  } catch (e) {
    const m = String(e?.message || e);
    out.innerHTML = `<p><b>Não consegui falar com o Gemini.</b></p>
      <p>${esc(m).slice(0, 300)}</p>
      <p>${m.includes('429') || /quota|exceeded/i.test(m)
        ? 'Limite do plano gratuito atingido — espere ~1 minuto e tente de novo.'
        : 'Tente novamente em instantes.'}</p>`;
  } finally {
    btn.disabled = false;
  }
}

/// Sincroniza o Oráculo com o estado global (horizonte, perfil, capital):
/// atualiza o contexto exibido e marca o plano anterior como desatualizado.
function sincronizarOraculo(marcarDesatualizado = true) {
  const ctx = $('ai-contexto');
  if (ctx && DATA) {
    ctx.textContent = `${riscoSel} · ` +
      `${DATA.horizontes[horizonte].label.toLowerCase()}` +
      (capital > 0 ? ` · R$ ${fmtNum(capital, 0)}` : '');
  }
  atualizarChatCtx();
  if (!marcarDesatualizado) return;
  for (const id of ['ai-out', 'oraculo-pos-out']) {
    const out = $(id);
    if (out && !out.classList.contains('hidden') &&
        !out.querySelector('.ai-stale')) {
      out.insertAdjacentHTML('afterbegin',
        '<div class="ai-stale">A seleção mudou — gere novamente para sincronizar.</div>');
    }
  }
}
$('btn-ai').onclick = gerarIA;

// ── radar de picos ────────────────────────────────────────────────────
function renderRadar() {
  const list = $('radar-list');
  const radar = DATA.radarPicos || [];
  if (!radar.length) {
    list.innerHTML = `<div class="radar-vazio">Nenhum ativo em estado
      esticado hoje — sem candidato a pico. O radar só fala quando o
      gráfico está em extremo E existem análogos históricos suficientes.</div>`;
    return;
  }
  list.innerHTML = radar.map((r) => {
    const topo = r.tipo === 'topo';
    return `<details class="radar-row" data-id="${esc(r.id)}">
      <summary>
        <span class="badge ${topo ? 'venda' : 'compra'}">
          ${icon(topo ? 'down' : 'up')} ${topo ? 'TOPO' : 'FUNDO'}</span>
        <span class="row-name">${esc(r.nome)}${r.ticker ? `<span class="tick">${esc(r.ticker)}</span>` : ''}</span>
        <span class="rr-meter"><span class="rr-fill ${r.tipo}" data-w="${(r.prob * 100).toFixed(0)}"></span>
          <span class="rr-pct">${fmtPct(r.prob, 0, false)}</span></span>
        <span class="chev">${icon('chevron')}</span>
      </summary>
      <div class="row-body">
        <p class="rr-sub">${topo ? 'Esticado para cima — probabilidade de virada para baixo'
          : 'Esticado para baixo — probabilidade de virada para cima'}
          em ~21 pregões: <b>${fmtPct(r.prob, 0, false)}</b>
          (n=${r.n} · mediana dos 21d seguintes: ${fmtPct(r.medianaFwd21)}).</p>
        <p class="rr-leituras">${r.leituras.map(esc).join(' · ')}</p>
        <div class="row-actions">
          <button class="btn-raiox" data-modal="${esc(r.id)}">${icon('chart')} Raio-X completo</button>
        </div>
      </div>
    </details>`;
  }).join('') +
  `<div class="radar-nota">Probabilidade empírica: em n episódios em que o
   gráfico esteve neste estado, a % indica quantas vezes veio a virada em
   ~21 pregões. 99% não existe em mercado — acima de 70% já é raro; trate
   como alerta forte, não como certeza.</div>`;
  requestAnimationFrame(() => requestAnimationFrame(() => {
    list.querySelectorAll('.rr-fill').forEach((f) => {
      f.style.width = f.dataset.w + '%';
    });
  }));
}
$('radar-list').addEventListener('click', (e) => {
  const raiox = e.target.closest('[data-modal]');
  if (raiox) openModal(raiox.dataset.modal);
});

// ── copiloto: minhas posições (journal + monitor) ─────────────────────
let posicoes = JSON.parse(localStorage.getItem('ql_pos') || '[]');
let historico = JSON.parse(localStorage.getItem('ql_hist') || '[]');
const salvarCopiloto = () => {
  localStorage.setItem('ql_pos', JSON.stringify(posicoes));
  localStorage.setItem('ql_hist', JSON.stringify(historico));
};

function opAtual(ativoId) {
  for (const h of Object.values(DATA?.horizontes || {})) {
    const o = h.oportunidades.find((x) => x.id === ativoId);
    if (o?.preco != null) return o;
  }
  return null;
}

function statusPos(p, op) {
  const atual = op?.preco;
  if (atual == null) return { txt: 'sem cotação', cls: 'flat', varr: null };
  const dir = p.dir === 'compra' ? 1 : -1;
  const varr = dir * (atual / p.entrada - 1);
  if (p.sl != null && (dir > 0 ? atual <= p.sl : atual >= p.sl)) {
    return { txt: 'STOP ROMPIDO — FECHE', cls: 'down', ic: 'stop', varr };
  }
  if (p.tp != null && (dir > 0 ? atual >= p.tp : atual <= p.tp)) {
    return { txt: 'ALVO ATINGIDO — realize', cls: 'up', ic: 'flag', varr };
  }
  if (op && ((p.dir === 'compra' && op.direcao === 'venda') ||
             (p.dir === 'venda' && op.direcao === 'compra'))) {
    return { txt: 'Sinal virou contra — feche', cls: 'down', ic: 'alert', varr };
  }
  if (p.sl != null && p.entrada !== p.sl) {
    const dist = dir > 0 ? (atual - p.sl) / (p.entrada - p.sl)
                         : (p.sl - atual) / (p.sl - p.entrada);
    if (dist < 0.35) {
      return { txt: 'Perto do stop', cls: 'flat', ic: 'alert', varr };
    }
  }
  return { txt: 'MANTER', cls: 'up', ic: 'check', varr };
}

const nivelFmt = (x) => x == null ? '—' : fmtNum(x, x >= 100 ? 0 : 4);

/// P&L e status de uma posição real do eToro (usa a cotação atual gravada).
function etoroStatus(p) {
  const cur = p.currentRate;
  if (cur == null || !p.openRate) {
    return { plPct: null, txt: 'sem cotação', cls: 'flat', ic: 'alert' };
  }
  const move = cur / p.openRate - 1;
  const plPct = (p.isBuy ? move : -move) * (p.leverage || 1);
  const dir = p.isBuy ? 1 : -1;
  if (p.stopLoss && (dir > 0 ? cur <= p.stopLoss : cur >= p.stopLoss)) {
    return { plPct, txt: 'STOP ROMPIDO — FECHE', cls: 'down', ic: 'stop' };
  }
  if (p.takeProfit && (dir > 0 ? cur >= p.takeProfit : cur <= p.takeProfit)) {
    return { plPct, txt: 'ALVO ATINGIDO — realize', cls: 'up', ic: 'flag' };
  }
  // perto do stop (dentro de 20% do caminho entrada→stop)
  if (p.stopLoss && p.openRate !== p.stopLoss) {
    const prog = dir > 0 ? (cur - p.stopLoss) / (p.openRate - p.stopLoss)
                         : (p.stopLoss - cur) / (p.stopLoss - p.openRate);
    if (prog < 0.2) return { plPct, txt: 'Perto do stop', cls: 'flat', ic: 'alert' };
  }
  return { plPct, txt: 'MANTER', cls: 'up', ic: 'check' };
}

function renderEtoroPortfolio() {
  const box = $('etoro-portfolio');
  if (!box) return;
  const pf = etoroPortfolio;
  if (!pf || !(pf.posicoes || []).length) { box.innerHTML = ''; return; }
  const nivel = (x) => x == null ? '—' : fmtNum(x, x >= 100 ? 0 : 4);
  const quando = pf.atualizadoEm
    ? new Date(pf.atualizadoEm).toLocaleString('pt-BR',
        { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })
    : '';
  const totalPl = pf.posicoes.reduce((a, p) => {
    const s = etoroStatus(p);
    return a + (s.plPct != null && p.amount ? s.plPct * p.amount : 0);
  }, 0);
  box.innerHTML = `
    <div class="etoro-head">
      <span class="etoro-tag">${icon('shield')} eToro · conta real</span>
      <span class="etoro-when">${pf.posicoes.length} posições · P&L aberto
        <b class="${totalPl >= 0 ? 'pl-pos' : 'pl-neg'}">US$ ${fmtNum(totalPl, 0)}</b>
        · sincronizado ${quando}</span>
    </div>` +
    pf.posicoes.map((p) => {
      const s = etoroStatus(p);
      const plCls = s.plPct == null ? '' : (s.plPct >= 0 ? 'pl-pos' : 'pl-neg');
      return `<details class="pos-row etoro">
      <summary>
        <span class="badge ${p.isBuy ? 'compra' : 'venda'}">${p.isBuy ? '▲ LONG' : '▼ SHORT'}</span>
        <span class="row-name">${esc(p.nome || '—')}${p.leverage > 1 ? `<span class="tick">X${p.leverage}</span>` : ''}</span>
        <span class="pos-kv"><b class="${plCls}">${s.plPct == null ? '—' : fmtPct(s.plPct)}</b><span>P&L</span></span>
        <span class="st-chip ${s.cls}">${icon(s.ic)} ${s.txt}</span>
        <span class="chev">${icon('chevron')}</span>
      </summary>
      <div class="row-body">
        <p class="det">entrada ${nivel(p.openRate)} → atual ${nivel(p.currentRate)}
          ${p.amount ? ` · ${fmtNum(p.amount, 0)} investido` : ''} · alavancagem X${p.leverage || 1}
          ${p.stopLoss ? ` · SL ${nivel(p.stopLoss)}` : ' · sem SL'}${p.takeProfit ? ` · TP ${nivel(p.takeProfit)}` : ' · sem TP'}
          ${p.openDate ? ` · aberta em ${fmtData(String(p.openDate).slice(0, 10))}` : ''}</p>
        <div class="row-actions">
          <button class="btn-raiox" data-mentor data-nome="${esc(p.nome || '')}">Orientação do Oráculo</button>
        </div>
      </div>
    </details>`;
    }).join('');
}

function renderPosicoes() {
  if (!DATA) return;
  renderEtoroPortfolio();
  const list = $('pos-list');
  if (!posicoes.length) {
    list.innerHTML = `<div class="pos-vazio">Nenhuma posição registrada.
      Use "Executei no eToro" numa ordem do ranking, ou adicione abaixo o
      que já está aberto na sua conta — o Copiloto avisa quando fechar.</div>`;
  } else {
    list.innerHTML = posicoes.map((p) => {
      const op = opAtual(p.ativoId);
      const st = statusPos(p, op);
      const plPct = st.varr == null ? null : st.varr * p.lev;
      const plRs = plPct == null || !p.valor ? null : p.valor * plPct;
      const cls = plPct == null ? '' : (plPct >= 0 ? 'pl-pos' : 'pl-neg');
      return `<details class="pos-row">
        <summary>
          <span class="badge ${p.dir}">${p.dir === 'compra' ? '▲ LONG' : '▼ SHORT'}</span>
          <span class="row-name">${esc(p.nome)}${p.ticker ? `<span class="tick">${esc(p.ticker)}</span>` : ''}</span>
          <span class="pos-kv"><b class="${cls}">${plPct == null ? '—' : fmtPct(plPct)}</b>
            <span>P&L${p.lev > 1 ? ' (X' + p.lev + ')' : ''}</span></span>
          <span class="st-chip ${st.cls}">${icon(st.ic)} ${st.txt}</span>
          <span class="chev">${icon('chevron')}</span>
        </summary>
        <div class="row-body">
          <p class="det">entrada ${nivelFmt(p.entrada)} → atual ${nivelFmt(op?.preco)}
            ${p.valor ? ` · R$ ${fmtNum(p.valor, 0)} investido` : ''}
            ${plRs != null ? ` · resultado <b class="${cls}">R$ ${fmtNum(plRs, 0)}</b>` : ''}
            ${p.sl != null ? ` · SL ${nivelFmt(p.sl)}` : ''}${p.tp != null ? ` · TP ${nivelFmt(p.tp)}` : ''}
            · aberta em ${fmtData(p.abertaEm)}</p>
          <div class="row-actions">
            <button class="btn-close-pos" data-fechar="${p.id}">Fechar posição (registrar)</button>
            <button class="btn-raiox" data-mentor-pos="${p.id}">Orientação do Oráculo</button>
            <button class="btn-raiox" data-modal="${esc(p.ativoId)}">${icon('chart')} Raio-X do ativo</button>
          </div>
        </div>
      </details>`;
    }).join('');
  }
  const hist = $('pos-hist');
  if (!historico.length) { hist.innerHTML = ''; return; }
  const total = historico.reduce((a, h) => a + (h.resultadoRs || 0), 0);
  const acertos = historico.filter((h) => (h.resultadoPct || 0) > 0).length;
  hist.innerHTML = `<div class="placar">${icon('book')} Histórico: ${historico.length}
    fechadas · acerto ${Math.round(acertos / historico.length * 100)}% ·
    resultado acumulado R$ ${fmtNum(total, 0)}</div>` +
    historico.slice(-8).reverse().map((h) => `<div class="h-row">
      ${esc(h.nome)} (${h.dir === 'compra' ? 'long' : 'short'}) ·
      ${fmtPct(h.resultadoPct)}${h.resultadoRs != null ? ` · R$ ${fmtNum(h.resultadoRs, 0)}` : ''}
      · fechada em ${fmtData(h.fechadaEm)}</div>`).join('');
}

function registrarExecucao(id) {
  const l = calcularOrdens(horizonte).linhas.find((x) => x.o.id === id);
  if (!l) return;
  posicoes.push({
    id: Date.now(), ativoId: l.o.id, nome: l.o.nome,
    ticker: l.o.etoro?.ticker || null,
    dir: l.o.recomendacao.acao === 'comprar' ? 'compra' : 'venda',
    entrada: l.o.preco, valor: l.margem, lev: l.lev,
    sl: l.stopPreco, tp: l.alvoPreco, abertaEm: DATA.ultimaObservacao,
  });
  salvarCopiloto();
  renderPosicoes();
  toast('Posição registrada no Copiloto — o painel avisa quando fechar.');
}

$('pos-list').addEventListener('click', (e) => {
  const raiox = e.target.closest('[data-modal]');
  if (raiox) { openModal(raiox.dataset.modal); return; }
  const mp = e.target.closest('[data-mentor-pos]');
  if (mp) {
    const p = posicoes.find((x) => x.id === +mp.dataset.mentorPos);
    if (p) {
      abrirMentor(`Tenho uma posição de ${p.dir === 'compra' ? 'COMPRA' : 'VENDA'} ` +
        `em ${p.nome} (entrada ${p.entrada}). Devo fechar, manter ou ` +
        'ajustar o stop agora? Explique como mentor.');
    }
    return;
  }
  const b = e.target.closest('[data-fechar]');
  if (!b) return;
  const p = posicoes.find((x) => x.id === +b.dataset.fechar);
  if (!p) return;
  const op = opAtual(p.ativoId);
  const st = statusPos(p, op);
  const plPct = st.varr == null ? null : st.varr * p.lev;
  historico.push({
    ...p, fechadaEm: DATA.ultimaObservacao, saida: op?.preco ?? null,
    resultadoPct: plPct,
    resultadoRs: plPct != null && p.valor ? p.valor * plPct : null,
  });
  posicoes = posicoes.filter((x) => x.id !== p.id);
  salvarCopiloto();
  renderPosicoes();
});

function preencherFormAtivos() {
  const vistos = new Set();
  const opts = [];
  for (const h of Object.values(DATA.horizontes)) {
    for (const o of h.oportunidades) {
      if (vistos.has(o.id)) continue;
      vistos.add(o.id);
      opts.push(`<option value="${esc(o.id)}">${esc(o.nome)}${o.etoro?.ticker ? ' · ' + esc(o.etoro.ticker) : ''}</option>`);
    }
  }
  $('pf-ativo').innerHTML = opts.join('');
}

$('pf-add').onclick = () => {
  const id = $('pf-ativo').value;
  const op = opAtual(id);
  const entrada = +$('pf-entrada').value;
  if (!op || !(entrada > 0)) { toast('Preencha o preço de entrada.'); return; }
  posicoes.push({
    id: Date.now(), ativoId: id, nome: op.nome,
    ticker: op.etoro?.ticker || null, dir: $('pf-dir').value,
    entrada, valor: +$('pf-valor').value || null, lev: +$('pf-lev').value,
    sl: null, tp: null, abertaEm: DATA.ultimaObservacao,
  });
  salvarCopiloto();
  renderPosicoes();
  toast('Posição adicionada ao Copiloto.');
};

async function oraculoPosicoes() {
  if (!DATA) return;
  if (!posicoes.length) {
    toast('Nenhuma posição registrada ainda — use "Executei no eToro" no ranking.');
    return;
  }
  const out = $('oraculo-pos-out');
  const btn = $('btn-oraculo-pos');
  out.classList.remove('hidden');
  out.innerHTML =
    '<div class="ai-loading">O Oráculo está avaliando suas posições…</div>';
  btn.disabled = true;
  try {
    const ctx = posicoes.map((p) => {
      const op = opAtual(p.ativoId);
      const st = statusPos(p, op);
      return {
        ativo: p.nome, ticker: p.ticker, direcao: p.dir,
        precoEntrada: p.entrada, precoAtual: op?.preco ?? null,
        alavancagem: 'X' + p.lev, valorInvestidoRs: p.valor,
        plPct: st.varr == null ? null : +(st.varr * p.lev * 100).toFixed(1),
        stopLoss: p.sl, takeProfit: p.tp, statusPainel: st.txt,
        sinalAtualDoLaboratorio: op ? {
          direcao: op.direcao,
          acao: op.recomendacao?.acao,
          assertividadePct:
            Math.round((op.recomendacao?.assertividade || 0) * 100),
          gatilho: op.recomendacao?.gatilho,
          radarDePico: op.radar ? {
            tipo: op.radar.tipo,
            probPct: Math.round((op.radar.prob || 0) * 100),
          } : null,
        } : null,
      };
    });
    const texto = await chamarGemini(
      `POSIÇÕES ABERTAS (cotações do fechamento de ${DATA.ultimaObservacao}): ${JSON.stringify(ctx)}
MACRO: ${JSON.stringify(DATA.macro)}
Dê o veredito de cada posição agora.`, ORACULO_POS_SYSTEM);
    out.innerHTML = mdParaHtml(texto) +
      '<div class="ai-meta">Oráculo (Gemini) · cotações do fechamento diário · não é recomendação de investimento</div>';
  } catch (e) {
    out.innerHTML = `<p><b>Não consegui falar com o Oráculo.</b></p>
      <p>${esc(String(e?.message || e)).slice(0, 300)}</p>`;
  } finally {
    btn.disabled = false;
  }
}
$('btn-oraculo-pos').onclick = oraculoPosicoes;

// ── mentor: chat do Oráculo (ao vivo, sincronizado com o painel) ──────
const ORACULO_MENTOR_SYSTEM =
  'Você é o ORÁCULO, mentor de investimentos do QuantLab, conversando ' +
  'com o dono da conta no eToro. Papel duplo: EXPLICAR como professor ' +
  '(por que os números dizem o que dizem) e ORIENTAR com ação concreta ' +
  '(comprar/vender/manter/fechar/aguardar, com valores, stop e gatilho ' +
  'quando existirem no contexto). REGRAS: use SOMENTE os dados do bloco ' +
  'CONTEXTO (nunca invente preços, notícias ou eventos); as cotações são ' +
  'do fechamento diário indicado — quando a decisão depender do preço de ' +
  'agora, mande conferir o preço atual no eToro antes de executar; se ' +
  'perguntarem sobre ativo fora do contexto, diga que o laboratório ' +
  'ainda não cobre esse ativo; sinais são de ciclo diário (nada de day ' +
  'trade); português do Brasil, tom direto e didático, no MÁXIMO ~180 ' +
  'palavras, markdown leve (negrito e listas curtas). Números SEMPRE no ' +
  'padrão brasileiro (162.885, nunca 162884.55; R$ 1.803). Feche sempre ' +
  'com uma linha começando com "Ação:" e, ao falar de posição aberta, dê ' +
  'o veredito MANTER / FECHAR / AJUSTAR STOP em negrito. Nunca prometa ' +
  'retorno.';

function contextoMentor() {
  const plano = calcularOrdens(horizonte);
  const ordens = plano.linhas.slice(0, 6).map((l) => ({
    ativo: l.o.nome, ticker: l.o.etoro?.ticker ?? null,
    acao: l.o.recomendacao.acao,
    assertividadePct: Math.round((l.o.recomendacao.assertividade || 0) * 100),
    investirRs: l.margem == null ? null : Math.round(l.margem),
    alavancagem: 'X' + l.lev,
    stopLoss: l.stopPreco, takeProfit: l.alvoPreco,
    gatilho: l.o.recomendacao.gatilho,
    radar: l.o.radar ? l.o.radar.tipo + ' ' +
      Math.round((l.o.radar.prob || 0) * 100) + '%' : null,
  }));
  const radar = (DATA.radarPicos || []).slice(0, 4).map((r) =>
    `${r.nome}: ${r.tipo} ${Math.round(r.prob * 100)}% (n=${r.n})`);
  const pos = posicoes.map((p) => {
    const op = opAtual(p.ativoId);
    const st = statusPos(p, op);
    return {
      ativo: p.nome, direcao: p.dir, entrada: p.entrada,
      atual: op?.preco ?? null,
      plPct: st.varr == null ? null : +(st.varr * p.lev * 100).toFixed(1),
      alavancagem: 'X' + p.lev, stopLoss: p.sl, takeProfit: p.tp,
      statusPainel: st.txt,
      sinalAtual: op?.recomendacao?.acao ?? null,
    };
  });
  const posEtoro = (etoroPortfolio?.posicoes || []).map((p) => {
    const s = etoroStatus(p);
    return {
      ativo: p.nome, direcao: p.isBuy ? 'compra' : 'venda',
      entrada: p.openRate, atual: p.currentRate,
      alavancagem: 'X' + (p.leverage || 1),
      stopLoss: p.stopLoss, takeProfit: p.takeProfit, valor: p.amount,
      plPct: s.plPct == null ? null : +(s.plPct * 100).toFixed(1),
      statusPainel: s.txt,
    };
  });
  return `CONTEXTO ATUAL (cotações do fechamento de ${DATA.ultimaObservacao}):
${JSON.stringify({
    selecao: {
      perfil: riscoSel,
      horizonte: DATA.horizontes[horizonte].label,
      capitalRs: capital > 0 ? capital : null,
      caixaSugeridoPct: Math.round(plano.caixaPct * 100),
    },
    macro: DATA.macro,
    ordensAprovadas: ordens,
    naoOperar: plano.segurados.map((o) => o.nome),
    radarDePicos: radar,
    posicoesReaisNoEtoro: posEtoro,
    posicoesManuais: pos,
  })}`;
}

const chatHist = [];

function atualizarChatCtx() {
  const el = $('chat-ctx');
  if (!el || !DATA) return;
  el.textContent = `${riscoSel} · ${DATA.horizontes[horizonte].label.toLowerCase()}` +
    (capital > 0 ? ` · R$ ${fmtNum(capital, 0)}` : '') +
    ` · dados de ${fmtData(DATA.ultimaObservacao)}`;
}

function chatMsg(role, html) {
  const box = $('chat-msgs');
  const div = document.createElement('div');
  div.className = 'msg ' + role;
  div.innerHTML = html;
  box.appendChild(div);
  box.scrollTop = box.scrollHeight;
  return div;
}

async function mentorPerguntar(texto) {
  if (!DATA || !texto.trim()) return;
  chatMsg('user', esc(texto));
  const load = chatMsg('model', 'Analisando o painel…');
  load.classList.add('loading');
  $('chat-send').disabled = true;
  try {
    const contents = [
      { role: 'user', parts: [{ text: contextoMentor() }] },
      { role: 'model', parts: [{ text: 'Contexto recebido.' }] },
      ...chatHist.slice(-8).map((m) => ({
        role: m.role, parts: [{ text: m.text }],
      })),
      { role: 'user', parts: [{ text: texto }] },
    ];
    const r = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: ORACULO_MENTOR_SYSTEM }] },
        contents,
        generationConfig: {
          temperature: 0.35,
          maxOutputTokens: 1200,
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.error?.message || ('HTTP ' + r.status));
    const t = (j.candidates?.[0]?.content?.parts || [])
      .map((p) => p.text || '').join('');
    if (!t) throw new Error('resposta vazia do modelo');
    load.classList.remove('loading');
    load.innerHTML = mdParaHtml(t);
    chatHist.push({ role: 'user', text: texto }, { role: 'model', text: t });
    if (chatHist.length > 12) chatHist.splice(0, chatHist.length - 12);
  } catch (e) {
    load.classList.remove('loading');
    load.innerHTML = '<b>Falha ao consultar o mentor.</b> ' +
      esc(String(e?.message || e)).slice(0, 200);
  } finally {
    $('chat-send').disabled = false;
    $('chat-msgs').scrollTop = $('chat-msgs').scrollHeight;
  }
}

function abrirChat() {
  $('chat-panel').classList.remove('hidden');
  $('fab-oraculo').classList.add('hidden');
  atualizarChatCtx();
  $('chat-inp').focus();
}
function fecharChat() {
  $('chat-panel').classList.add('hidden');
  if (!$('dash').classList.contains('hidden')) {
    $('fab-oraculo').classList.remove('hidden');
  }
}
function abrirMentor(pergunta) {
  abrirChat();
  if (pergunta) mentorPerguntar(pergunta);
}
$('fab-oraculo').onclick = abrirChat;
$('chat-close').onclick = fecharChat;
const enviarChat = () => {
  const inp = $('chat-inp');
  const t = inp.value.trim();
  if (!t) return;
  inp.value = '';
  mentorPerguntar(t);
};
$('chat-send').onclick = enviarChat;
$('chat-inp').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') enviarChat();
});
function ligarBotaoMentor(container) {
  container.addEventListener('click', (e) => {
    const m = e.target.closest('[data-mentor]');
    if (m) {
      abrirMentor(`O que devo fazer com ${m.dataset.nome} agora? ` +
        'Explique como mentor e diga a ação concreta.');
    }
  });
}
ligarBotaoMentor($('modal-body'));
ligarBotaoMentor($('etoro-portfolio'));

// ── PWA ───────────────────────────────────────────────────────────────
if ('serviceWorker' in navigator && location.protocol === 'https:') {
  navigator.serviceWorker.register('/sw.js').catch(() => {});
}

// ── contadores do hero ────────────────────────────────────────────────
document.querySelectorAll('[data-count]').forEach((el) => {
  const target = +el.dataset.count;
  const t0 = performance.now();
  const tick = (t) => {
    const p = Math.min((t - t0) / 900, 1);
    el.textContent = nf.format(Math.round(target * (1 - Math.pow(1 - p, 3))));
    if (p < 1) requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
});
