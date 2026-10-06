# Classificação por etapas — RQ3

Instrumento **ml-stages-1.0.0**, preparado para piloto e validação humana.
RQ3: a quais etapas do desenvolvimento de IA/ML/LLM se referem as preocupações
com legislação de privacidade presentes nas discussões?

Referência: Amershi et al. (2019), *Software Engineering for Machine Learning:
A Case Study*, seção II.B e Figura 1,
[DOI 10.1109/ICSE-SEIP.2019.00042](https://doi.org/10.1109/ICSE-SEIP.2019.00042),
[fonte primária](https://www.microsoft.com/en-us/research/publication/software-engineering-for-machine-learning-a-case-study/).
As definições operacionais, critérios regulatórios, IDs, estados, regras de
evidência e adaptações para LLM são desta pesquisa. O artigo não é apresentado
como autor desses instrumentos nem como validação desta adaptação.

Definições, inclusões, exclusões e exemplos LLM estão em
[config/development-stages.yml](../../config/development-stages.yml) e são
exportados em `development-stages.csv`. Não são regras automáticas.

| ID estável | Etapa |
|---|---|
| S01 | Requisitos do modelo |
| S02 | Coleta de dados |
| S03 | Limpeza de dados |
| S04 | Rotulagem de dados |
| S05 | Engenharia de características |
| S06 | Treinamento |
| S07 | Avaliação |
| S08 | Implantação |
| S09 | Monitoramento |

## Unidade, leitura e independência

Use as mesmas discussões fechadas elegíveis do estudo-base adaptado:
Issue no GitHub ou Discussion de modelo/dataset no HF, iniciada por autor
não identificado como bot e sem pull request. Leis, direitos/princípios,
keywords, 24 categorias e filtros de coleta continuam preservados.
Não atribua etapa pelo hub, licença, popularidade ou tipo de repositório.

Leia título, texto inicial e contexto dos comentários. Artefatos, datas,
URLs e papéis da fonte constam de `coding-sources.csv`. Para RQ1, não confunda
texto inicial e contexto. No HF, `unresolved_context` indica que o início
não foi comprovado por tipo, autoria e data. Comentários automatizados de
discussões humanas não são descartados indiscriminadamente.

Dois avaliadores independentes devem avaliar **todas as unidades únicas**
da amostra sem consultar a decisão do outro. Preserve uma linha por unidade
e avaliador, inclusive pendências. Categorias `C01`–`C24` e etapas `S01`–`S09`
são eixos distintos: uma categoria não determina uma etapa.

O mesmo trecho pode sustentar mais de uma etapa quando relaciona a preocupação
a ambas. Não presuma todas as atividades posteriores. Etapas podem se repetir
e não pressupõem processo linear. Casos não cobertos pela taxonomia original
não autorizam criar ou renomear categorias durante esta anotação.

## Campos e estados

Preserve `unit_key`, dados de origem, `reviewer`, `codebook_version` original,
`stage_codebook_version` e `stage_codebook_hash`. Os dois últimos identificam
esta adaptação sem alterar a identidade da coleta.

| Estado | Relevância | Etapas/evidência | Significado |
|---|---|---|---|
| `pending` | vazio, 0 ou 1 | vazias | Avaliação de etapas ainda incompleta |
| `identified` | 1 | IDs; evidência para cada ID | Atividade identificável no conteúdo |
| `indeterminate` | 1 | IDs vazios; evidência com `stage_id=indeterminate` e justificativa em `notes` | Avaliação concluída, sem etapa identificável |
| `not_applicable` | 0 | vazias | Discussão avaliada como não relevante |

`indeterminate` é um estado, não uma décima etapa, e não pode coexistir
com IDs identificados. `stages` recebe IDs separados por `;`, sem repetição.
Pendências não devem receber rótulos provisórios no campo definitivo.

`stage_evidence` é uma lista JSON. Esta é somente a sintaxe, **não uma
anotação ou evidência real**:

```json
[{"stage_id":"S02","artifact_key":"ID_REAL_DO_ARTEFATO","excerpt":"TRECHO_LITERAL_DO_ARTEFATO"}]
```

Inclua pelo menos uma entrada por etapa. Indique o artefato da mesma discussão
e copie literalmente um trecho não vazio. A importação confere pertencimento
e presença literal; não avalia automaticamente se a interpretação humana
é correta. A presença de um trecho não substitui justificar a relação
entre preocupação e atividade.

Após as avaliações independentes, registre uma linha por unidade em
`consensus.csv`, com `reviewer` identificando o responsável e `notes`
registrando discussão/adjudicação, inclusive nos acordos. Linhas pendentes
podem ter responsável ainda vazio. Consenso concluído só é importado
quando os dois avaliadores concluíram a unidade. Preserve as decisões iniciais.

Planilhas anteriores ao instrumento continuam válidas no fluxo original.
Falta de etapas é pendência da RQ3, sem presumir classificação ou modificar
a coleta. Alterações de significado exigem nova versão e validação explícita,
com IDs estáveis. Versão/hash incompatíveis impedem importação/exibição silenciosa.

## Concordância e descrição

Calcule concordância **antes do consenso**, por etapa e por hub.
Acordo bruto é a proporção de concordâncias entre pares elegíveis. Cohen's
kappa é `(observado − esperado)/(1 − esperado)`, com marginais dos dois
avaliadores, sem usar consenso.

Para uma etapa, 1 indica ID atribuído e 0 indica ID ausente em uma
classificação identificada. Um par exige ambos julgarem a discussão relevante
e identificarem etapas. Indeterminação não significa ausência das etapas;
não relevantes e pendentes também não viram negativos artificiais.
Informe pares, amostra, pendências e avaliações indeterminadas. Sem pares
ou com acordo esperado igual a 1, kappa é indefinido com motivo.
Cobertura de toda a amostra difere de número de pares elegíveis.

Descrições usam o consenso efetivamente importado. Por hub:

- `n_sample`: unidades únicas selecionadas.
- `n_relevant`: consenso de relevância 1, inclusive etapas ainda pendentes.
- `n_relevant_annotated`/`denominator`: relevantes com estado `identified` ou `indeterminate`.
- `n_stage`: relevantes associadas ao ID; proporção `n_stage/denominator`.
- `n_indeterminate`, `n_stage_pending`, `n_relevance_pending` e
  `n_not_relevant`: situações separadas.

As proporções descrevem a amostra manual sem pesos. Não estimam a população
automaticamente: múltiplos estratos legais e deduplicação exigem considerar
probabilidades de inclusão. A soma multilabel pode superar 100%.
Denominador zero gera proporção indefinida; contagem zero permanece válida.
Relações e exemplos preservam unidade, projeto, URL, artefato, avaliador e
versão. Trechos individuais não são publicados na página.

## Contrastes pré-especificados

Família: **S01, S02, S03, S04, S05, S06, S07, S08 e S09**, cada uma em
um contraste bilateral GitHub × HF. Para cada ID:

- **H0:** a proporção de discussões relevantes associadas à etapa é igual
  nos dois hubs.
- **H1:** essa proporção difere entre os hubs.

O estimando é a diferença entre proporções de discussões relevantes
associadas à etapa em projetos comparáveis, considerando seleção,
classificação multilabel e dependência entre discussões do mesmo projeto.
`descriptive_difference` é somente a diferença na amostra, em pontos
de proporção (0,10 corresponde a 10 pontos percentuais).

Antes de inferir, fixe e verifique: tipos/finalidades de projetos comparáveis;
identidade dos projetos e vínculos entre repositórios/hubs; seleção e
probabilidades de inclusão; suficiência de projetos independentes e variação
das respostas; tratamento de pendências e indeterminados; método que preserve
clusters por projeto e vínculos entre hubs; efeito e intervalo; família e
correção de **Holm**. Tipos comparáveis não são deduzidos de `repository`,
`model` ou `dataset`. Estabeleça o protocolo estatístico antes de examinar
diferenças. Não trate threads do mesmo projeto como réplicas independentes
nem teste ingenuamente tabelas de contagens multilabel.

O mapeamento e desenho inferencial não estão disponíveis no software atual.
Os nove contrastes registram `not_testable`, com motivo
`human_annotation_pending`, `no_relevant_discussions` ou
`project_comparability_and_cluster_design_pending`. Intervalos e p-valores,
inclusive o campo reservado a Holm, ficam indefinidos. Registrar a hipótese
não equivale a executar o teste.

Sem dados adequados, apresente descrição e impedimento. Zero relevantes
no HF é válido e não produz falha de coleta. Diferenças não estabelecem
conformidade jurídica ou maior preocupação de uma comunidade. OSS geral
integra RQ1/RQ2; não há RQ4 nem comparação antes/depois da GDPR.
