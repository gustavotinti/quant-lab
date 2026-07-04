// QuantLab dashboard — vanilla JS + Firebase Auth (Google).
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js';
import {
  getAuth, GoogleAuthProvider, signInWithPopup, onAuthStateChanged, signOut,
} from 'https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js';

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
  macro: $('macro-strip'), cards: $('cards'), hipoteses: $('hipoteses'),
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
    if (e.code === 'auth/operation-not-allowed' || e.code === 'auth/configuration-not-found') {
      toast('Login Google ainda não está ativado no console do Firebase ' +
            '(Authentication → Sign-in method → Google).', 9000);
    } else if (e.code !== 'auth/popup-closed-by-user' && e.code !== 'auth/cancelled-popup-request') {
      toast('Falha no login: ' + (e.code || e.message));
    }
  }
}
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
  <div class="card ${neutro ? 'neutro' : ''}" data-dir="${dir}" style="transition-delay:${Math.min(i * 45, 400)}ms">
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
    ${cen12 ? `<div class="cen-line">12m após análogos: mediana <b>${fmtPct(cen12.mediana)}</b>
      [${fmtPct(cen12.q1)} … ${fmtPct(cen12.q3)}] · ${fmtPct(cen12.pctPositivo, 0, false)} subiram</div>` : ''}
    ${o.evidencias?.length ? `<details class="evid"><summary>evidências (${o.evidencias.length})</summary>
      <ul>${o.evidencias.map((e) => `<li>${esc(e)}</li>`).join('')}</ul></details>` : ''}
  </div>`;
}

function render() {
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
