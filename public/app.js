// QuantLab dashboard — vanilla JS + Firebase Auth (Google) + Gemini
// (Gemini Developer API direto, free tier, chave restrita por domínio).
import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.4.0/firebase-app.js';
import {
  getAuth, GoogleAuthProvider, signInWithPopup, signInWithRedirect,
  getRedirectResult, onAuthStateChanged, signOut,
} from 'https://www.gstatic.com/firebasejs/12.4.0/firebase-auth.js';

const app = initializeApp({
  projectId: 'quantlab-lde',
  appId: '1:1025412444243:web:e1fcf413f6144e524a96a6',
  apiKey: 'AIzaSyA1EcBYGb5sdH9KEqfmDFaWQrUQGSyO7fk',
  authDomain: 'quantlab-lde.firebaseapp.com',
});
const auth = getAuth(app);

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
  if (logged) {
    els.userPhoto.src = user.photoURL || '';
    els.userName.textContent = (user.displayName || user.email || '').split(' ')[0];
    loadData();
  }
});

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
  els.updated.textContent =
    `dados até ${fmtData(DATA.ultimaObservacao)} · gerado ${fmtData(DATA.geradoEm?.slice(0, 10))}`;
  renderMacro();
  render();
  renderHipoteses();
  if (location.hash.startsWith('#a=')) openModal(location.hash.slice(3));
}

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
  const wr = o.estrategia?.winRate;
  const fav = o.cenarios?.fwd3m?.pctFavoravel;
  const cen12 = o.cenarios?.fwd12m;
  const s = o.sinais || {};

  return `
  <div class="card ${neutro ? 'neutro' : ''}" data-dir="${dir}" data-id="${esc(o.id)}" style="transition-delay:${Math.min(i * 45, 400)}ms">
    <div class="card-top">
      <div>
        <h3>${esc(o.nome)}</h3>
        <div class="cat">${esc(o.categoria)} · ${esc(o.unidade)}</div>
        <div class="preco">${fmtNum(o.preco)} · ${fmtData(o.dataPreco)}</div>
      </div>
      <span class="badge ${dir}">${badgeTxt[dir]}</span>
    </div>
    <div class="card-mid">
      <div class="ring ${dir}">
        <svg width="74" height="74">
          <circle class="track" r="32" cx="37" cy="37" fill="none" stroke-width="7"/>
          <circle class="bar" r="32" cx="37" cy="37" fill="none" stroke-width="7"
            stroke-dasharray="${C}" stroke-dashoffset="${C}" data-off="${C * (1 - score / 100)}"/>
        </svg>
        <div class="num">${neutro ? '—' : Math.round(score)}<small>convicção</small></div>
      </div>
      <div class="effs">
        <div class="eff">
          <div class="eff-lbl"><span>Eficácia · ${esc(o.estrategia?.nome || 'estratégia')}</span>
            <b>${wr == null ? 'n/d' : fmtPct(wr, 0, false)}${o.estrategia?.trades ? ` · ${o.estrategia.trades} trades` : ''}</b></div>
          <div class="eff-bar"><div class="eff-fill ${effClass(wr)}" data-w="${wr == null ? 0 : wr * 100}"></div></div>
        </div>
        <div class="eff">
          <div class="eff-lbl"><span>Cenários análogos a favor (3m)</span>
            <b>${fav == null ? 'n/d' : fmtPct(fav, 0, false)}${o.cenarios?.n ? ` · n=${o.cenarios.n}` : ''}</b></div>
          <div class="eff-bar"><div class="eff-fill ${effClass(fav)}" data-w="${fav == null ? 0 : fav * 100}"></div></div>
        </div>
        ${!neutro && o.alavancagem ? `<span class="lev">⚡ alavancagem ≤ ${fmtNum(o.alavancagem.sugerida)}x</span>` : ''}
      </div>
    </div>
    <div class="mini">
      <div><div class="k">Mom 12-1</div><div class="v">${fmtPct(s.mom12x1)}</div></div>
      <div><div class="k">vs SMA-200</div><div class="v">${fmtPct(s.distSma200)}</div></div>
      <div><div class="k">Vol 1a</div><div class="v">${fmtPct(s.vol1y, 0, false)}</div></div>
      <div><div class="k">Do topo</div><div class="v">${fmtPct(s.ddTopo)}</div></div>
    </div>
    ${sparkSvg(o)}
    ${cen12 ? `<div class="cen-line">12m após análogos: mediana <b>${fmtPct(cen12.mediana)}</b>
      [${fmtPct(cen12.q1)} … ${fmtPct(cen12.q3)}] · ${fmtPct(cen12.pctPositivo, 0, false)} subiram</div>` : ''}
    ${o.evidencias?.length ? `<details class="evid"><summary>evidências (${o.evidencias.length})</summary>
      <ul>${o.evidencias.map((e) => `<li>${esc(e)}</li>`).join('')}</ul></details>` : ''}
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
// Risco fixo por trade (padrão profissional): peso = riscoPorTrade / stop,
// limitado por posição e pelo teto investido do perfil; o resto é caixa.
const perfis = {
  conservador: { corte: 0.65, risco: 0.005, maxPeso: 0.15, teto: 0.40 },
  moderado: { corte: 0.55, risco: 0.01, maxPeso: 0.25, teto: 0.70 },
  agressivo: { corte: 0.55, risco: 0.02, maxPeso: 0.35, teto: 1.00 },
};
let capital = +(localStorage.getItem('ql_capital') || 0);

function renderRanking() {
  const p = perfis[riscoSel];
  const ops = DATA.horizontes[horizonte].oportunidades;
  const ordens = ops
    .filter((o) => ['comprar', 'vender'].includes(o.recomendacao?.acao) &&
        (o.recomendacao.assertividade || 0) >= p.corte)
    .sort((a, b) => (b.recomendacao.retornoEsperado ?? -9) -
        (a.recomendacao.retornoEsperado ?? -9));
  const segurados = ops.filter((o) => o.direcao !== 'neutro' &&
    (o.recomendacao?.acao === 'ficarDeFora' ||
     (['comprar', 'vender'].includes(o.recomendacao?.acao) &&
      (o.recomendacao.assertividade || 0) < p.corte)));

  // pesos por risco fixo, renormalizados se passarem do teto do perfil
  let pesos = ordens.map((o) =>
    Math.min(p.risco / (o.recomendacao.stopEstimado || 0.05), p.maxPeso));
  const soma = pesos.reduce((a, b) => a + b, 0);
  if (soma > p.teto) pesos = pesos.map((w) => w * p.teto / soma);

  let html = `<h2 class="rank-title">O que fazer agora —
    ${DATA.horizontes[horizonte].label.toLowerCase()} · perfil ${riscoSel}</h2>`;
  if (!ordens.length) {
    html += `<div class="rank-empty">Nenhuma ordem passa no corte de
      assertividade do perfil ${riscoSel} (${Math.round(p.corte * 100)}%)
      neste horizonte — o laboratório prefere ficar de fora a chutar.</div>`;
  } else {
    html += ordens.map((o, i) => {
      const r = o.recomendacao;
      const tk = o.etoro?.ticker;
      const peso = pesos[i];
      const valor = capital > 0 ? capital * peso : null;
      const riscoRs = valor != null ? valor * (r.stopEstimado || 0.05) : null;
      const sizing = valor != null
        ? `Posição sugerida: <b>R$ ${fmtNum(valor, 0)}</b> (${fmtPct(peso, 1, false)})
           · risco até o stop ≈ R$ ${fmtNum(riscoRs, 0)}`
        : `Peso sugerido: <b>${fmtPct(peso, 1, false)}</b> do capital
           (informe o capital acima para ver em R$)`;
      return `<div class="rank-row" data-id="${esc(o.id)}">
        <div class="rank-pos">${i + 1}</div>
        <span class="badge ${o.direcao}">${r.acao === 'comprar' ? '▲ COMPRAR' : '▼ VENDER (SHORT)'}</span>
        <div class="rank-name">${esc(o.nome)}${tk ? `<span class="tick">eToro: ${esc(tk)}</span>` : ''}</div>
        <div class="rank-kv"><b>${fmtPct(r.retornoEsperado)}</b><span>retorno esp. (${r.janelaRetorno})</span></div>
        <div class="rank-kv rank-ass"><b>${fmtPct(r.assertividade, 0, false)}</b><span>assertividade · n=${r.base}</span></div>
        <div class="rank-kv"><b>${r.stopEstimado ? fmtPct(r.stopEstimado, 0, false) : '—'}</b><span>stop estim.</span></div>
        <div class="rank-kv"><b>${o.alavancagem ? '≤' + fmtNum(o.alavancagem.sugerida) + 'x' : '—'}</b><span>alav. máx.</span></div>
        <div class="rank-gat"><span class="rank-sizing">${sizing}</span><br>
          → ${esc(r.gatilho || '')}${o.etoro?.nota ? ` · <i>${esc(o.etoro.nota)}</i>` : ''}</div>
      </div>`;
    }).join('');
    const investido = pesos.reduce((a, b) => a + b, 0);
    const caixaPct = Math.max(0, 1 - investido);
    html += `<div class="rank-caixa">🏦 Caixa/renda fixa: <b>${fmtPct(caixaPct, 0, false)}</b>
      ${capital > 0 ? `(R$ ${fmtNum(capital * caixaPct, 0)})` : ''} —
      com juro real de ${fmtPct(DATA.macro?.juroReal, 1, false)} a.a., caixa
      também é posição.</div>`;
  }
  if (segurados.length) {
    html += `<div class="rank-fora">Sinal presente mas abaixo do corte de
      ${Math.round(p.corte * 100)}% do perfil: ${segurados.map((o) => esc(o.nome)).join(', ')} — ficar de fora.</div>`;
  }
  els.ranking.innerHTML = html;
}

const capInput = $('capital');
if (capital > 0) capInput.value = capital;
capInput.addEventListener('input', () => {
  capital = +capInput.value || 0;
  localStorage.setItem('ql_capital', String(capital));
  if (DATA) renderRanking();
});
els.ranking?.addEventListener('click', (e) => {
  const row = e.target.closest('.rank-row[data-id]');
  if (row) openModal(row.dataset.id);
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
    els.cards.querySelectorAll('.eff-fill').forEach((f) => { f.style.width = f.dataset.w + '%'; });
  }));
}

els.tabs.addEventListener('click', (e) => {
  const t = e.target.closest('.tab');
  if (!t) return;
  horizonte = t.dataset.h;
  els.tabs.querySelectorAll('.tab').forEach((x) => x.classList.toggle('active', x === t));
  render();
});
els.filters.addEventListener('click', (e) => {
  const c = e.target.closest('.chip');
  if (!c) return;
  filtro = c.dataset.f;
  els.filters.querySelectorAll('.chip').forEach((x) => x.classList.toggle('active', x === c));
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
      <ul class="m-evid">${o.evidencias.map((x) => `<li>${esc(x)}</li>`).join('')}</ul>` : ''}`;
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
  'Você é o consultor quantitativo do QuantLab. Responda em português ' +
  'do Brasil, em markdown enxuto com as seções: ## Leitura do momento, ' +
  '## Alocação sugerida, ## O que evitar, ## Gatilhos de saída. ' +
  'REGRAS INEGOCIÁVEIS: use SOMENTE os dados fornecidos no prompt ' +
  '(nunca invente números, notícias ou preços); cite sempre a ' +
  'assertividade e o n dos ativos que recomendar; use o ticker do eToro ' +
  'quando existir; a alocação deve somar 100% incluindo o percentual em ' +
  'caixa/renda fixa (cite o juro real fornecido); respeite o perfil de ' +
  'risco pedido; termine com UMA linha de aviso de risco. ' +
  'Expresse assertividade e percentuais SEMPRE como porcentagem ' +
  'arredondada (ex.: 77%, nunca 0.765714) e valores no padrão brasileiro. ' +
  'Máximo de ~300 palavras.';

let riscoSel = 'moderado';
let tempoSel = 'medio';

async function chamarGemini(prompt) {
  const r = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: AI_SYSTEM }] },
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
    'no máximo 1x mesmo que a sugerida seja maior; máximo 25% por ativo; ' +
    'mantenha reserva em caixa.',
  agressivo:
    'PERFIL AGRESSIVO: além do ranking, pode citar sinais segurados pelo ' +
    'corte de 55% como posições especulativas de no máximo 5% cada, ' +
    'deixando claro o risco; alavancagem até a máxima sugerida de cada ' +
    'ativo; máximo 35% por ativo.',
};

function aiPrompt() {
  const h = DATA.horizontes[tempoSel];
  const ops = h.oportunidades.map((o) => ({
    nome: o.nome,
    etoro: o.etoro?.ticker ?? null,
    acao: o.recomendacao?.acao,
    assertividade: o.recomendacao?.assertividade,
    n: o.recomendacao?.base,
    retornoEsperado: o.recomendacao?.retornoEsperado,
    janelaRetorno: o.recomendacao?.janelaRetorno,
    stopEstimado: o.recomendacao?.stopEstimado,
    payoff: o.recomendacao?.payoff,
    conviccao: o.score,
    direcao: o.direcao,
    alavancagemMax: o.alavancagem?.sugerida ?? 0,
    gatilho: o.recomendacao?.gatilho,
    vol1a: o.sinais?.vol1y,
  }));
  return `${regrasPerfil[riscoSel]}
HORIZONTE PEDIDO: ${h.label} (${h.janela}).
MACRO (dados oficiais): ${JSON.stringify(DATA.macro)}
ATIVOS (ranking do laboratório, dados reais): ${JSON.stringify(ops)}
Monte a recomendação agora.`;
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
  out.innerHTML = '<div class="ai-loading">✨ Analisando os números do '
    + 'laboratório com o Gemini…</div>';
  btn.disabled = true;
  try {
    const texto = await chamarGemini(aiPrompt());
    out.innerHTML = mdParaHtml(texto) +
      `<div class="ai-meta">Gerado por IA (Gemini) a partir dos dados do
       painel · perfil ${riscoSel} · ${DATA.horizontes[tempoSel].label.toLowerCase()}
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

for (const [segId, setter] of [
  // o perfil de risco também re-dimensiona as posições do ranking
  ['seg-risco', (v) => { riscoSel = v; if (DATA) renderRanking(); }],
  ['seg-tempo', (v) => { tempoSel = v; }],
]) {
  $(segId).addEventListener('click', (e) => {
    const b = e.target.closest('button[data-v]');
    if (!b) return;
    setter(b.dataset.v);
    $(segId).querySelectorAll('button')
      .forEach((x) => x.classList.toggle('active', x === b));
  });
}
$('btn-ai').onclick = gerarIA;

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
