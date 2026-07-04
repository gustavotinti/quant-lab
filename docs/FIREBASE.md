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

## Deploy

```bash
# da raiz do repo — atualiza o relatório publicado e sobe o site
dart run lab_cli:lab report
cp reports/relatorio_$(date +%F).md public/relatorio.txt
firebase deploy --only hosting -P quantlab-lde

# regras do Firestore
firebase deploy --only firestore -P quantlab-lde
```

## Pendências da Fase 3

- **Cloud Function agendada** (cron diário: update → engines → Firestore +
  relatório no Hosting): exige plano **Blaze** (precisa de cartão no
  console — ação manual do Gustavo). Custo esperado ≈ zero no volume atual.
- Auth Google (entra junto com o app Flutter, Fase 4).
- Espelho público no Firestore (`opportunities`, `hypotheses`, `pulse`)
  com regras `read: true` apenas no que for exibível.
