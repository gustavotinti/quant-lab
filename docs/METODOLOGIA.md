# Metodologia

Tudo que o QuantLab exibe é derivado das fórmulas abaixo — sem exceção e
sem parâmetro escondido. Janelas em pregões: 21 ≈ 1 mês, 63 ≈ 3 meses,
252 ≈ 1 ano.

## Sinais por ativo (`AssetSignals`)

| Sinal | Definição |
|---|---|
| Momentum 12-1 | `p[t-21] / p[t-252] - 1` (12 meses excluindo o último — evita a reversão de curtíssimo prazo documentada na literatura) |
| Distância SMA-200 | `p / SMA200 - 1` |
| Z-score 60d | `(p - média60) / desvio60` |
| Vol anualizada | desvio padrão amostral dos retornos diários × √252 |
| Drawdown do topo | `p / máx histórico - 1` |
| CAGR 3 anos | `(p[t]/p[t-756])^(1/3) - 1` |

## Regime macro

- **Juro real (ex-post):** `(1 + Selic) / (1 + IPCA12m) - 1`
- **IPCA 12m:** composição das 12 variações mensais; **3m anualizado:**
  trimestre composto elevado à 4ª potência. Inflação "subindo" quando o 3m
  anualizado excede o 12m em mais de 0,5 p.p.
- **Direções** (Selic, Treasury): valor atual vs ~63 pregões atrás, com
  bandas mortas (0,01 p.p. Selic; 0,10 p.p. Treasury).

## Nota de oportunidade (0–100)

Cada componente é `tanh(medida / escala) × peso` (contribuição em [-1, 1];
positivo = compra). Soma → direção (banda morta de ±0,15 → NEUTRO) e
convicção (|soma| × 100).

- **Curto (≤3m):** reversão à média (−z60/2, peso 0,45) + retorno 1m
  (peso 0,25) + tendência SMA-200 (peso 0,20). Vol 30d > 60% a.a. corta a
  convicção em 30% (ruído > sinal).
- **Médio (3–18m):** momentum 12-1 (peso 0,45) + SMA-200 (peso 0,30) +
  ajuste macro por classe (±0,10–0,15: direção da Selic p/ Ibovespa, juro
  real p/ dólar, Treasury p/ ações EUA e metais, DXY p/ commodities e
  cripto) + reversão leve (peso 0,10).
- **Longo (>18m):** CAGR 3 anos (peso 0,45) + distância do topo em ativo
  com tendência secular positiva (peso 0,30 — entrada, não fuga) +
  SMA-200 (peso 0,15) + macro (×0,7).
- **Freio de robustez:** se a estratégia de tendência do ativo NÃO
  sobreviveu fora da amostra, a convicção cai 30% e a falha é exibida como
  evidência.

## Backtests por estratégia

Três regras mensuráveis, sempre decididas com dados até o fechamento de
ontem (sem viés de antecipação); caixa rende 0, sem custos — medem poder
preditivo do sinal, não corretagem:

| Estratégia | Regra | Usada no horizonte |
|---|---|---|
| Tendência | comprado se fechamento > SMA-200 | longo |
| Momentum 12-1 | comprado se momentum 12-1 > 0 | médio |
| Reversão à média | compra z-60 < −1,5 **somente acima da SMA-200**; vende z-60 > +1,5 **somente abaixo**; zera em z = 0 | curto |

O filtro de tendência na reversão é obrigatório: numa tendência suave o
preço fica permanentemente ~1,7σ acima da média da própria janela — sem o
filtro, a regra venderia contra altas persistentes (defeito detectado por
teste sintético antes de ir para produção).

Métricas no período inteiro, **nos 30% finais (OOS)** e em **walk-forward
de 3 janelas contíguas** (um sinal robusto tem Sharpe positivo na maioria
das janelas, não só no agregado). O μ da alavancagem e o freio de robustez
de cada horizonte vêm da estratégia correspondente.

### Incerteza do Sharpe

IC 90% via **bootstrap de blocos móveis** (blocos de 21 pregões, 500
reamostragens, seed fixo → reproduzível). Blocos preservam a
autocorrelação de curto prazo que o bootstrap i.i.d. destruiria.

## Alavancagem sugerida

Dois freios independentes; **vale o menor**, com teto absoluto de 3x
(1x quando vol > 40% a.a.):

1. **Meio-Kelly:** `f* = μ/σ²` com μ = CAGR da estratégia de tendência
   (edge mensurável, validado OOS) e σ = vol 1 ano do ativo; usa-se `f*/2`.
2. **Alvo de volatilidade:** `15% a.a. ÷ vol do ativo`.

Kelly ≤ 0 ⇒ alavancagem 0 ("matematicamente não alavancar"). Avisos de
liquidação sempre presentes.

## Cenários análogos

Em vez de prever, o sistema pergunta: *"quantas vezes este ativo já esteve
numa situação parecida com a de hoje — e o que aconteceu depois?"*

1. "Situação" = vetor (momentum 12-1, distância da SMA-200, z-60).
2. Análogo = data histórica cuja soma das distâncias normalizadas (em
   desvios padrão de cada sinal) é ≤ 1,5.
3. Episódios espaçados ≥ 21 pregões (o mesmo evento não conta duas vezes).
4. Saída: distribuição empírica dos retornos 3m/12m seguintes — mediana,
   quartis, % positivos, pior e melhor caso, com n explícito.

É uma distribuição condicional histórica, não uma previsão pontual.

## Laboratório de hipóteses

1. Cada série vira **variação mensal** (retorno log para preços; diferença
   para taxas em %) — nunca níveis.
2. Para cada par ordenado (causa → efeito) e lag 1–6 meses: Spearman no
   **treino (70% inicial)**, registrando TODOS os testes executados.
3. **Correção de Benjamini-Hochberg** sobre o universo inteiro de
   p-valores de treino (FDR ≤ 5%): quando centenas de pares são testados,
   alguns "significativos" aparecem por acaso — a correção descarta esses.
   Exige ainda |ρ| ≥ 0,25 e n ≥ 48.
4. **Tentativa de destruição:** recalcula no **teste (30% final)**. Sinal
   invertido ⇒ hipótese destruída (não é salva). |ρ teste| ≥ 0,15 ⇒
   `validada`; senão `candidata`.
5. Correlação não é causalidade: hipótese validada é um **candidato a
   estudo**, não um gatilho de operação.

## Limitações conhecidas (honestidade metodológica)

- Backtests não incluem custos, impostos, slippage nem carrego do caixa.
- μ do Kelly vem do passado; regimes mudam sem avisar.
- Múltiplos testes inflam falsos positivos — Benjamini-Hochberg + split
  treino/teste mitigam bastante, mas não eliminam (o próprio universo de
  indicadores foi escolhido por um humano).
- Séries do Yahoo começam em ~2006 (20 anos) — ciclos anteriores ficam de
  fora até integrarmos fontes mais longas (FRED).
