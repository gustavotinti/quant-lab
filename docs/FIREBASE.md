# Firebase — projeto `quantlab-lde`

Criado em 04/07/2026, conta `gustavo.a.tinti3@gmail.com`. Separado do
Desafio Pago (`desafio-app-b8665`) de propósito — nada se mistura.

- Console: https://console.firebase.google.com/project/quantlab-lde/overview
- **Hosting no ar: https://quantlab-lde.web.app** (landing + relatório do dia
  em `/relatorio.txt`)
- Firestore: banco `(default)` criado (nam5/us-central), regras **fechadas**
  (`firestore.rules` — todo acesso de cliente negado até o app Flutter
  definir o espelho público)
- App Web registrado (config abaixo é pública por natureza — a segurança
  vem das regras, não do sigilo da config):

```json
{
  "projectId": "quantlab-lde",
  "appId": "1:1025412444243:web:e1fcf413f6144e524a96a6",
  "storageBucket": "quantlab-lde.firebasestorage.app",
  "apiKey": "AIzaSyA1EcBYGb5sdH9KEqfmDFaWQrUQGSyO7fk",
  "authDomain": "quantlab-lde.firebaseapp.com",
  "messagingSenderId": "1025412444243"
}
```

## Deploy do site/dashboard

```bash
# da raiz do repo — gera dashboard.json + relatório e sobe o site
dart run lab_cli:lab update    # dados frescos
dart run lab_cli:lab publish   # public/data/dashboard.json + relatorio.txt
firebase deploy --only hosting -P quantlab-lde

# regras do Firestore
firebase deploy --only firestore -P quantlab-lde
```

## Dashboard web (public/)

SPA vanilla (index.html + styles.css + app.js) com Firebase Auth Google
(SDK modular v10 via CDN). O painel (oportunidades LONG/SHORT com % de
eficácia, macro, hipóteses) só aparece logado; os dados vêm de
`/data/dashboard.json` gerado pelo `lab publish`. Obs.: o JSON em si é
público no Hosting — o login é porta de UX, não de segurança (nada ali é
sensível). Gate de verdade virá com Firestore + regras.

## ⚠️ Ativar o login Google (1 minuto, manual)

A API identitytoolkit já foi habilitada via REST, mas o provedor Google
exige um OAuth client que SÓ o console cria automaticamente:

1. https://console.firebase.google.com/project/quantlab-lde/authentication
2. "Começar" (se aparecer) → aba **Sign-in method** → **Google** →
   **Ativar** → salvar (e-mail de suporte: gustavo.a.tinti3@gmail.com).

Sem isso o botão de login mostra o aviso "ainda não ativado no console".

## Pendências da Fase 3

- **Cloud Function agendada** (cron diário: update → engines → publish no
  Hosting/Firestore): exige plano **Blaze** (cartão no console — manual).
  Obs.: `initializeAuth` do Identity Platform também pede billing.
- Espelho público no Firestore (`opportunities`, `hypotheses`) com regras
  `read` só para autenticados — aí o gate vira de verdade.
