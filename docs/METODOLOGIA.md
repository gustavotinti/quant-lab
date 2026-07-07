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
- **Cenários análogos no score:** a mediana e a % de altas dos episódios
  historicamente parecidos (3m no curto; 12m no médio/longo) entram como
  componente (pesos 0,15 + 0,10) — a história condicional puxa a nota.
- **Confluência:** contam-se os sinais relevantes (|contribuição| ≥ 0,02)
  a favor e contra a direção final; a nota é multiplicada por
  `0,7 + 0,3·(a favor / total)`. Sinais independentes concordando valem
  mais que um sinal isolado gritando.
- **Freio de robustez:** se a estratégia do horizonte NÃO sobreviveu fora
  da amostra, a convicção cai 30% e a falha é exibida como evidência.

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

### Eficácia (%)

Duas medidas independentes, sempre com o *n* ao lado:

- **Eficácia da estratégia**: fração dos trades fechados que terminaram no
  lucro (na direção da posição — um short que caiu conta como acerto).
  Com menos de 5 trades vira "n/d", nunca um número enganoso.
- **Cenários análogos a favor**: fração dos episódios historicamente
  parecidos com hoje cujo retorno de 3 meses foi na direção apontada
  (numa VENDA, "a favor" = caiu).

### Incerteza do Sharpe

IC 90% via **bootstrap de blocos móveis** (blocos de 21 pregões, 500
reamostragens, seed fixo → reproduzível). Blocos preservam a
autocorrelação de curto prazo que o bootstrap i.i.d. destruiria.

## Alavancagem preditiva (degraus do eToro)

Com o risco por trade fixado pelo stop, alavancar **não aumenta a perda
planejada** — o dimensionador reduz a margem na mesma proporção (margem =
exposição ÷ X). O degrau só sobe quando a evidência autoriza:

- **X2**: sobreviveu fora da amostra E walk-forward ≥ 2/3 E assertividade
  ≥ 60% E meio-Kelly ≥ 1 E vol anual ≤ 30% (a liquidação em X2 exige
  ~50% adverso — muito além de qualquer stop do sistema);
- **X5**: tudo acima E walk-forward 3/3 E assertividade ≥ 70% E
  meio-Kelly ≥ 2,5 E vol ≤ 20% (raro por construção);
- caso contrário, **X1**. O perfil limita: conservador X1, moderado ≤X2,
  agressivo ≤X5.

## Sobre "lucro diário" (honestidade)

Os sinais do laboratório são de **fechamento diário** — não existe aqui
um preditor intradiário validado, e prometê-lo seria inventar precisão.
O ciclo rentável honesto é diário: atualizar dados → executar o plano →
Copiloto monitora → fechar no gatilho/stop/alvo. Day trade de varejo tem
evidência estatística amplamente negativa; o Oráculo é instruído a dizer
isso se solicitado.

## Assertividade da recomendação e política de emissão

Cada recomendação carrega **uma única % de assertividade**, combinando as
evidências de eficácia disponíveis ponderadas pelo tamanho das amostras,
com suavização de Laplace centrada em 50% (k = 10):

```
assertividade = (wr·nT + fav·nA + 0,5·k) / (nT + nA + k)
```

- `wr` = taxa de acerto dos trades históricos **na direção da ordem**
  (compras e vendas medidas separadamente; se não há 5+ trades na direção,
  usa-se a taxa geral da estratégia);
- `fav` = % dos cenários análogos que andaram na direção da ordem (janela
  de 3m no curto; 12m no médio/longo);
- a suavização impede que amostras minúsculas gerem números espetaculares
  (6 acertos em 6 → ~69%, nunca 100%).

**Política de emissão:** um sinal só vira ordem (COMPRAR / VENDER) se a
assertividade for ≥ 55%. Abaixo disso: FICAR DE FORA (o sinal aparece,
mas "segurado"). Sem base histórica mensurável: OBSERVAR. O ranking
acionável ordena por assertividade, não por convicção.

## Retorno esperado, payoff e dimensionamento de posição

Acertar muito não basta — importa o **quanto** se ganha quando acerta:

- **Retorno esperado**: mediana dos retornos que se seguiram aos cenários
  análogos, na direção da ordem (3m no curto; 12m no médio/longo). O
  ranking acionável ordena por ele (entre as ordens que passaram no corte
  de assertividade).
- **Payoff**: ganho médio dos trades vencedores ÷ perda média dos
  perdedores, por direção (57% de acerto com payoff 1:1 rende menos que
  45% com 3:1).
- **Stop estimado**: distância até a invalidação técnica do sinal —
  SMA-200 para tendência/momentum; 1σ de 60 pregões para reversão
  (limitado a 2%–25%).
- **Dimensionamento (risco fixo por trade)**: peso = risco-por-trade ÷
  stop, limitado por posição e pelo teto investido do perfil
  (conservador: 0,5% de risco, corte 65%, teto 40% investido; moderado:
  1%, 55%, 70%; agressivo: 2%, 55%, 100%). Nenhuma **classe de ativo**
  (ações, cripto, commodities…) pode passar de metade do teto investido —
  diversificação obrigatória. O que sobra é caixa — que, com juro real
  alto, também é posição.
- **Preços de execução**: Stop Loss = preço × (1 ∓ stop estimado);
  alvo (Take Profit) = preço × (1 ± retorno esperado) — na direção da
  ordem. Sem retorno esperado mensurável, a saída é só pelo gatilho.

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
