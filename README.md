<h1 align="center">Leis de privacidade em projetos Open Source de IA/ML</h1>

<p align="center">Pipeline de pesquisa em R para encontrar e analisar menções a leis de privacidade em issues do GitHub e Discussions do Hugging Face.</p>

<p align="center">
  <a href="https://diegopn.github.io/msr-oss-privacy-legislation-ai-ml-gh-hf/">Abrir resultados</a> ·
  <a href="config/">Consultar o protocolo</a> ·
  <a href="#como-executar">Executar o pipeline</a>
</p>

<p align="center">
  <a href="https://www.r-project.org/"><img alt="R 4.6.0 ou superior" src="https://img.shields.io/badge/R-4.6.0%2B-276DC3?style=for-the-badge&logo=r&logoColor=white"></a>
  <a href="https://quarto.org/"><img alt="Quarto" src="https://img.shields.io/badge/Quarto-39729E?style=for-the-badge&logo=quarto&logoColor=white"></a>
  <a href="https://docs.github.com/en/rest"><img alt="GitHub REST API" src="https://img.shields.io/badge/GitHub_API-181717?style=for-the-badge&logo=github&logoColor=white"></a>
  <a href="https://huggingface.co/docs/hub"><img alt="Hugging Face Hub API" src="https://img.shields.io/badge/Hugging_Face_API-FFD21E?style=for-the-badge&logo=huggingface&logoColor=111111"></a>
  <a href="https://www.sqlite.org/"><img alt="SQLite" src="https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white"></a>
  <a href="LICENSE"><img alt="Licença MIT" src="https://img.shields.io/badge/License-MIT-2ea44f?style=for-the-badge&logo=opensourceinitiative&logoColor=white"></a>
</p>

Este projeto investiga como desenvolvedores discutem leis e preocupações de privacidade em projetos públicos de IA/ML. O pipeline pesquisa e coleta conteúdo de issues do GitHub e de Discussions do Hugging Face, seleciona uma amostra e prepara os dados para análise e publicação em um site Quarto.

> **Como interpretar os dados:** uma menção a uma lei é evidência de uma discussão textual. Ela não demonstra, por si só, conformidade ou violação legal. Os critérios de descoberta e a cobertura da coleta ainda precisam de validação empírica.

## Visão geral

| Etapa | O que acontece | Resultado |
|---|---|---|
| Descoberta | Localiza conversas públicas com termos de leis de privacidade e aplica critérios de escopo para IA/ML. | Candidatos elegíveis por plataforma. |
| Coleta | Recupera o texto inicial, comentários ou mensagens, datas e metadados necessários para auditoria. | Bancos SQLite e respostas brutas por execução. |
| Amostragem | Estratifica unidades com evidência legal por plataforma, tipo de repositório e lei. | População, amostra e manifesto reproduzível. |
| Análise | Organiza evidências para responder às questões de pesquisa. | Tabelas, figuras, relatórios e site Quarto. |

## Perguntas de pesquisa

| Questão | O que será observado |
|---|---|
| **RQ1** | Quais direitos e princípios de privacidade aparecem? O texto inicial é separado dos comentários. |
| **RQ2** | Quais preocupações aparecem e como se relacionam às 24 categorias do estudo-base? |
| **RQ3** | A quais das nove etapas do desenvolvimento de IA/ML/LLM as preocupações se referem? |

GitHub e Hugging Face contribuem para as três questões. A comparação com projetos Open Source em geral é usada em RQ1 e RQ2.

## Estrutura do repositório

A organização acompanha o caminho dos dados: configuração do protocolo, coleta, tratamento e análise ficam em `src/`; os dados e resultados ficam em `inputs/` e `outputs/`; os arquivos de apresentação ficam em `site/`.

| Caminho | Função |
|---|---|
| `main.R` | Entrada de linha de comando e execução do pipeline. |
| `config/` | Protocolo, termos, leis, critérios, limites e parâmetros. |
| `src/` | Aplicação, clientes das APIs, coleta, seleção, análise, armazenamento e relatórios. |
| `inputs/` | Bancos, amostras, respostas brutas e arquivos de coleta. |
| `outputs/` | Tabelas, figuras, relatórios e metadados derivados. |
| `site/`, `_site/` | Fontes da página e site renderizado pelo Quarto. |
| `tests/` | Contratos e testes com respostas simuladas das APIs. |

## Instalação

### Pré-requisitos

| Ferramenta | Requisito | Para que serve |
|---|---|---|
| R | 4.6.0 ou superior | Executar coleta e análise. |
| Quarto | Versão atual | Pré-visualizar ou renderizar o site. |
| Git | Instalado no sistema | Baixar o repositório. |

### Baixar o projeto

Execute no terminal:

```bash
git clone https://github.com/diegopn/msr-oss-privacy-legislation-ai-ml-gh-hf.git
cd msr-oss-privacy-legislation-ai-ml-gh-hf
```

### Instalar as dependências do R

No console do R, instale `pak` e as versões usadas pelo projeto:

```r
install.packages("pak", repos = "https://cloud.r-project.org")
pak::pkg_install(c(
  "R6@2.6.1", "yaml@2.3.12", "jsonlite@2.0.0", "httr2@1.3.0",
  "DBI@1.3.0", "RSQLite@3.53.3", "digest@0.6.39",
  "testthat@3.3.2", "cyclocomp@1.1.1"
))
```

### Configurar os tokens

As coletas usam `GITHUB_TOKEN` e `HF_TOKEN`. Crie o arquivo local a partir do modelo:

```bash
cp .env.example .env
```

No Windows PowerShell, use `Copy-Item .env.example .env`. Edite `.env` e preencha os valores. O arquivo é ignorado pelo Git; não publique tokens em issues, logs ou commits. Os tokens não são gravados nas respostas, manifestos ou no site. Sem token, as APIs aplicam as cotas anônimas.

## Como executar

Rode os comandos a partir da raiz do repositório. Consulte primeiro a ajuda:

```bash
Rscript main.R --help
```

Sem argumentos, `main.R` também exibe a ajuda. A tabela mostra o efeito de cada modo:

| Comando | O que faz |
|---|---|
| `Rscript main.R --pilot` | Faz uma coleta limitada em bancos de piloto separados; não gera o site nem altera os bancos oficiais ou as planilhas de análise. Substitui os artefatos do piloto anterior. |
| `Rscript main.R --github` | Inicia uma nova coleta oficial do GitHub e atualiza o banco dessa plataforma. |
| `Rscript main.R --huggingface` | Inicia uma nova coleta oficial do Hugging Face e atualiza o banco dessa plataforma. |
| `Rscript main.R --analyze` | Lê os bancos existentes, prepara as análises e renderiza o site. Não inicia uma coleta. |
| `Rscript main.R --run` | Executa as duas coletas oficiais em sequência e depois analisa os dados e gera o site. |
| `Rscript main.R --internal tests` | Executa os contratos e testes com APIs simuladas, sem chamadas às APIs externas. |

### Testar o fluxo com um piloto

Antes de iniciar uma coleta integral, execute:

```bash
Rscript main.R --pilot
```

O piloto é uma prévia técnica, não uma estimativa da cobertura, do tempo ou do consumo de cota da coleta integral.

### Coletar as plataformas em paralelo

Se quiser separar a coleta por plataforma, abra dois terminais na pasta do projeto:

```bash
# Terminal 1
Rscript main.R --github
```

```bash
# Terminal 2
Rscript main.R --huggingface
```

Depois que as duas coletas terminarem, execute a análise:

```bash
Rscript main.R --analyze
```

Cada nova coleta reinicia a plataforma selecionada. Não existe retomada automática de uma coleta parcial. Use `--run` para fazer as duas coletas em sequência ou os três comandos acima para coletá-las em paralelo.

### Visualizar ou renderizar o site

Depois de preparar os dados, execute na raiz:

```bash
quarto preview
quarto render
```

`quarto preview` abre uma prévia local; `quarto render` gera os arquivos estáticos em `_site/`. A renderização local não cria commits nem publica o site.

## Protocolo de coleta

O protocolo ativo é a versão **1.3.0**. Termos, leis, licenças, conceitos, taxonomia, limites e etapas estão definidos em [`config/`](config/). O corte inclusivo da coleta é **22/09/2026 UTC** e se aplica à data do conteúdo, não à data de criação do repositório.

### Critérios por plataforma

| Critério | GitHub | Hugging Face |
|---|---|---|
| Escopo comum | Repositório público, licença SPDX aprovada pela lista OSI local e evidência de finalidade em IA/ML. Cada identificador de uma expressão de licença precisa ser aprovado. | Os mesmos critérios comuns; os tipos de repositório considerados são modelos, datasets, Spaces e Kernels. |
| Unidade procurada | Issues públicas fechadas que contenham termos legais; o repositório precisa ter sinal de IA/ML e evidência técnica. A issue não precisa mencionar IA. | Discussions fechadas em repositórios elegíveis. |
| Exclusões e tratamento | Pull requests e autores identificados como bots são excluídos; comentários de bots podem fornecer evidência. A coleta lê manifestos na raiz e o README quando necessário, sem percorrer código ou subdiretórios. | Pull requests e autores-bot são excluídos; comentários de bots são preservados. Buckets não entram porque não têm Discussions. O status gated é registrado quando disponível, mas não exclui o repositório. |
| Falhas e datas | Datas ausentes ou inválidas não comprovam elegibilidade. | Repositórios sem endpoint acessível de Discussions são excluídos da população elegível; falhas técnicas ficam registradas como lacunas. |

Menções legais são confirmadas no conteúdo coletado. O processo não conclui conformidade jurídica. Não há corte por popularidade; um tópico de IA/ML é sinal de descoberta, não prova automática do escopo técnico.

## Piloto, paginação e limites

Os valores abaixo limitam apenas o piloto; não são tetos da coleta oficial.

| Limite do piloto | GitHub | Hugging Face |
|---|---:|---:|
| Resultados de busca por termo / repositórios descobertos por tipo | 1.000 | 1.000 por tipo |
| Issues / Discussions processadas | Até 100 issues | Até 20 Discussions por repositório |
| Repositórios elegíveis processados | — | Até 1.000 por tipo |
| Comentários processados | Até 20 por issue | — |

As APIs ainda impõem limites por chamada, como 100 itens por página e 1.000 resultados por busca do GitHub. Na coleta oficial, as buscas são subdivididas quando alcançam esse limite e paginadas para recuperar a população. No fim da coleta do GitHub, o programa faz duas passagens de nova tentativa para itens pendentes, dentro dos orçamentos configurados.

Pendências que não puderem ser resolvidas ficam registradas como pendentes ou inconclusivas e fora da população analítica. Elas não invalidam automaticamente toda a coleta concluída. O resumo aparece no terminal e no banco.

Antes da primeira coleta oficial completa das duas plataformas, o site usa o piloto como prévia preliminar. A transição para dados oficiais é registrada; depois dela, a geração do site falha se os dados oficiais necessários estiverem ausentes, sem voltar ao piloto.

## Amostra e arquivos de saída

A amostra é composta por unidades com evidência legal e estratificada por plataforma, tipo de repositório e lei. O tamanho segue Cochran com correção para população finita, usando 99% de confiança, margem de 5%, proporção de 50%, amostragem sem reposição e a semente `20260920` acrescida do índice do estrato.

| Caminho | Conteúdo e uso |
|---|---|
| `inputs/data/github.sqlite` | Banco oficial da coleta do GitHub. |
| `inputs/data/huggingface.sqlite` | Banco oficial da coleta do Hugging Face. |
| `inputs/data/latest-collection-*.json` | Registro da coleta mais recente por plataforma. |
| `inputs/data/archive/` | Bancos anteriores e snapshots oficiais usados pelo site. |
| `inputs/data/pilot/` | Banco e resumo da tentativa de piloto mais recente. |
| `inputs/raw/` | Respostas recebidas das APIs por execução. |
| `inputs/final/collection/` | População, amostra, planilhas e manifesto da coleta. |
| `outputs/` | Tabelas, figuras, relatórios e metadados derivados. |
| `site/` e `_site/` | Fontes do site e saída renderizada pelo Quarto. |

## Site e publicação

A [página de resultados](https://diegopn.github.io/msr-oss-privacy-legislation-ai-ml-gh-hf/) apresenta os dados e relatórios gerados. Para abrir uma prévia ou gerar o site localmente, use os comandos da seção [Como executar](#como-executar).

O workflow [check.yml](.github/workflows/check.yml) executa os testes offline em pull requests e em atualizações de `main`. Após os testes passarem em `main`, [quarto-publish.yml](.github/workflows/quarto-publish.yml) renderiza e publica a página no GitHub Pages. A geração local não cria commits nem publica o site.

## Referências e sua relação com o estudo

As publicações orientam conceitos e métodos; os critérios executados e seus parâmetros estão no protocolo versionado em `config/`.

| Referência | Contribuição para este projeto |
|---|---|
| Amershi et al. (2019), [*Software Engineering for Machine Learning: A Case Study*](https://doi.org/10.1109/ICSE-SEIP.2019.00042) | Contextualiza práticas e etapas de engenharia de software para ML, relacionadas ao foco de RQ3. |
| Cohen (1960), [*A Coefficient of Agreement for Nominal Scales*](https://doi.org/10.1177/001316446002000104) | Referência sobre concordância em categorias nominais. |
| Cochran (1977), *Sampling Techniques* (3ª ed., Wiley) | Fundamenta o cálculo do tamanho da amostra com correção para população finita. |
| Gebru et al. (2021), [*Datasheets for Datasets*](https://doi.org/10.1145/3458723) e Mitchell et al. (2019), [*Model Cards for Model Reporting*](https://doi.org/10.1145/3287560.3287596) | Referências sobre documentação de datasets e modelos, relevantes ao contexto de IA/ML. |
| Herwanto et al. (2024), [*Toward a Holistic Privacy Requirements Engineering Process*](https://doi.org/10.1109/ACCESS.2024.3380888) e Kosenkov et al. (2026), [*Privacy by design*](https://doi.org/10.1016/j.infsof.2025.107946) | Situam privacidade e requisitos de software no campo de engenharia de software. |
| Kapitsaki (2026), [*Regulatory compliance-readiness in the AI Supply Chain*](https://arxiv.org/abs/2607.03310) | Estudo relacionado a documentação e conformidade em repositórios do Hugging Face. |
| Kapitsaki et al. (2026), [*Analyzing developer discussions on EU and US privacy legislation compliance in GitHub repositories*](https://doi.org/10.1016/j.infsof.2026.108252) | Trabalho relacionado à análise de discussões sobre legislação de privacidade no GitHub; inclui um [pacote de replicação](https://github.com/gkapi/github-privacy-law-issues-analysis). |

## Apoio

Se este projeto contribuir para sua pesquisa ou para o uso da ferramenta, você pode apoiar sua manutenção pelo [GitHub Sponsors](https://github.com/sponsors/diegopn).

<p align="left">
  <a href="https://github.com/sponsors/diegopn"><img alt="Apoie o projeto" src="https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white"></a>
</p>

## Segurança

Consulte a [política de segurança](SECURITY.md) para ver o escopo e como relatar uma vulnerabilidade de forma privada.

## Licença

Distribuído sob a [Licença MIT](LICENSE).
