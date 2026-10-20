# Legislação de privacidade em projetos Open Source de IA/ML

Programa em **R com R6** para identificar menções a GDPR, CCPA, CPRA e Data
Protection Act em issues do GitHub e Discussions do Hugging Face. Registra
evidências, seleciona repositórios e prepara arquivos para análise.

Menções textuais não indicam conformidade ou violação legal. A seleção de
projetos de IA/ML e a cobertura da descoberta ainda exigem validação empírica.

## Questões de pesquisa

| Questão | Foco |
|---|---|
| RQ1 | Quais direitos e princípios de privacidade são mencionados? O texto inicial é separado dos comentários. |
| RQ2 | Quais preocupações aparecem e como se relacionam às 24 categorias do estudo-base? |
| RQ3 | A quais das nove etapas do desenvolvimento de IA/ML/LLM as preocupações se referem? |

GitHub e Hugging Face integram as três questões. A comparação com projetos Open
Source em geral integra RQ1 e RQ2.

## Requisitos e instalação

Requer **R 4.6.0 ou superior**. Para gerar ou visualizar o site, instale também
o [Quarto](https://quarto.org/). Pacotes diretos e versões de referência:

| Pacote | Versão | Uso |
|---|---:|---|
| `R6` | 2.6.1 | Programa |
| `yaml` | 2.3.12 | Programa |
| `jsonlite` | 2.0.0 | Programa |
| `httr2` | 1.3.0 | Programa |
| `DBI` | 1.3.0 | Programa |
| `RSQLite` | 3.53.3 | Programa |
| `digest` | 0.6.39 | Programa |
| `testthat` | 3.3.2 | Testes |
| `cyclocomp` | 1.1.1 | Testes |

Instale as versões de referência e dependências com `pak`:

```bash
Rscript -e 'install.packages("pak", repos="https://cloud.r-project.org"); pak::pkg_install(c("R6@2.6.1", "yaml@2.3.12", "jsonlite@2.0.0", "httr2@1.3.0", "DBI@1.3.0", "RSQLite@3.53.3", "digest@0.6.39", "testthat@3.3.2", "cyclocomp@1.1.1"))'
```

Configure `GITHUB_TOKEN` e `HF_TOKEN` no ambiente ou em `.env` criado a partir
de `.env.example`. Tokens não são gravados nas respostas, manifestos ou no site.
Sem token, as coletas ficam sujeitas às cotas anônimas das plataformas.

## Execução

Use `main.R`. Sem argumentos, ele mostra a ajuda. Execute uma modalidade por vez.

| Modalidade | Comando | Resultado |
|---|---|---|
| Piloto | `Rscript main.R --pilot` | Coleta limitada em banco separado; não gera o site |
| GitHub | `Rscript main.R --github` | Atualiza GitHub e gera o site |
| Hugging Face | `Rscript main.R --huggingface` | Atualiza Hugging Face e gera o site |
| Análise | `Rscript main.R --analyze` | Prepara análises e site com coletas existentes |
| Completa | `Rscript main.R --run` | Coleta as duas plataformas, analisa e gera o site |

Cada nova coleta recomeça a plataforma selecionada. Não há retomada automática
de uma coleta parcial. O piloto substitui os dados do piloto anterior, mas não
altera os dados científicos nem as planilhas de análise.

Para ajuda e prévia local:

```bash
Rscript main.R --help
quarto preview
```

## Critérios de coleta

O protocolo ativo é `1.3.0`. Datas, termos legais, listas de IA/ML, licenças,
conceitos, taxonomia, limites e instrumento de etapas ficam em `config/`.
A coleta usa o corte inclusivo de **22/09/2026 UTC**, aplicado ao conteúdo, não
à criação do repositório.

- **Critério comum:** repositório público, licença SPDX aprovada pela lista OSI
  local e evidência de finalidade em IA/ML. Cada identificador de uma expressão
  de licença precisa ser aprovado. Não há corte por popularidade.
- **GitHub:** busca global por termos legais em issues públicas fechadas. O
  repositório precisa de sinal de IA/ML e evidência técnica; a issue não precisa
  mencionar IA. Pull requests e autores identificados como bots são excluídos.
  Comentários de bots podem fornecer evidência. A coleta lê manifestos na raiz
  e README quando necessário, sem percorrer código ou subdiretórios.
- **Hugging Face:** modelos, datasets, Spaces e Kernels com Discussions.
  Discussões precisam estar fechadas; pull requests e autores-bot são excluídos,
  mas comentários de bots são preservados. Buckets não entram porque não têm
  Discussions; Spaces gated são excluídos. Os metadados variam entre tipos.
  A rota de listagem de Kernels usada pelo coletor não consta entre os métodos
  gerais documentados pela API; paginação e cobertura ainda precisam de
  validação ao vivo antes de uma coleta integral ser reconhecida.
- **Conteúdo:** datas ausentes ou inválidas não comprovam elegibilidade.
  Menções legais são confirmadas no conteúdo coletado. O processo não conclui
  conformidade jurídica.

## Amostra e arquivos

A amostra usa unidades com evidência legal, estratificadas por plataforma,
tipo de repositório e lei. O tamanho segue Cochran com correção para população
finita (99% de confiança, margem de 5% e proporção de 50%), sem reposição e
com semente 20260920 acrescida do índice do estrato.

| Caminho | Conteúdo |
|---|---|
| `inputs/data/research.sqlite` | Banco científico atual |
| `inputs/data/archive/` | Bancos anteriores e snapshot da fonte oficial do site |
| `inputs/data/pilot/` | Banco e resumo da última tentativa piloto |
| `inputs/raw/` | Respostas das APIs por execução |
| `inputs/final/collection/` | População, amostra, planilhas e manifesto |
| `outputs/` | Tabelas, figuras, relatórios e metadados |
| `site/` e `_site/` | Fontes do site e página gerada |

Cada piloto remove os artefatos do piloto anterior antes de começar. A última
tentativa, inclusive se falhar, fica em `inputs/data/pilot/` e `inputs/raw/pilot/`.
Falhas de coleta não substituem o banco científico válido.

O site usa o piloto como prévia preliminar até a primeira execução completa das
duas plataformas, sem limites de piloto e com cobertura e paginação verificadas.
A transição é registrada e o snapshot oficial fica fora das pastas apagadas por
novos pilotos. Depois dela, o site nunca volta ao piloto; se os dados oficiais
faltarem, a geração falha com diagnóstico explícito.

## Paginação e limites do piloto

Páginas de 100 itens não limitam a população. Buscas GitHub são subdivididas
quando atingem o limite de resultados; falhas de paginação ou respostas
incompletas impedem validar a cobertura. As chamadas respeitam cotas e repetem
falhas transitórias dentro dos limites configurados.

| Limite do piloto | GitHub | Hugging Face |
|---|---:|---:|
| Resultados de busca por termo / repositórios descobertos por tipo | 1.000 | 1.000 por tipo |
| Issues / Discussions processadas | Até 100 no piloto | Até 20 por repositório |
| Repositórios elegíveis processados | — | Até 1.000 por tipo |
| Comentários processados | Até 20 por issue | — |

Os limites servem para testar o fluxo. O piloto não estima cobertura, tempo nem
consumo de cota da coleta integral.

## Site e automação

`quarto render` gera `_site/index.html`; `quarto preview` abre uma prévia local.
O workflow de testes roda em pull requests e em cada push para `main`. Após
testes aprovados em `main`, um workflow separado publica o site no GitHub Pages.
Renderizar localmente não cria commits nem publica o projeto.

## Referências

As referências científicas usadas pelo projeto estão em
[`inputs/reference/literature_methods.md`](inputs/reference/literature_methods.md).
