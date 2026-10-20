# Legislação de privacidade em projetos Open Source de IA/ML

Projeto em **R com R6** para identificar menções a GDPR, CCPA, CPRA e Data
Protection Act em issues do GitHub e Discussions dos repositórios do
Hugging Face. Preserva as respostas da coleta, confirma menções textuais e
prepara uma amostra estratificada e exportações para análises posteriores.

Uma menção não estabelece conformidade ou violação legal. A precisão da
identificação de IA/ML e a cobertura da descoberta por licença precisam de
validação empírica.

Cada repositório recebe uma decisão automática de elegibilidade ou exclusão,
com o motivo registrado. Evidência insuficiente de IA/ML resulta em exclusão
documentada; a coleta não cria uma fila de revisão de repositórios.
Os conceitos são registrados nas unidades principais, comentários e eventos,
com origem identificável. As exportações separam título/texto inicial do
contexto dos comentários para RQ1, sinalizando texto inicial HF não comprovado.

RQ1 trata dos direitos e princípios mencionados; RQ2, das preocupações e da
cobertura da taxonomia original; RQ3, das etapas às quais as preocupações se
referem. GitHub × Hugging Face integra as três RQs. A comparação com OSS em
geral integra RQ1 e RQ2. Não há RQ4 ou experimento antes/depois da GDPR.

## Requisitos e instalação

R ≥ 4.6.0. Quarto precisa estar no PATH para renderizar o site, que é atualizado
automaticamente ao concluir uma coleta completa ou uma análise. Não é necessário
usar RStudio ou um arquivo `.Rproj`. A CI usa R 4.6.1.

| Pacote | Versão de referência | Uso |
|---|---:|---|
| `R6` | 2.6.1 | Produção |
| `yaml` | 2.3.12 | Produção |
| `jsonlite` | 2.0.0 | Produção |
| `httr2` | 1.3.0 | Produção |
| `DBI` | 1.3.0 | Produção |
| `RSQLite` | 3.53.3 | Produção |
| `digest` | 0.6.39 | Produção |
| `testthat` | 3.3.2 | Somente testes da CI |
| `cyclocomp` | 1.1.1 | Somente testes da CI |

Instale os pacotes diretos nas versões de referência. O `pak` também instala as
dependências indiretas exigidas por eles ([documentação de versões e pacotes do
pak](https://pak.r-lib.org/reference/pak_package_sources.html)); não é
dependência do programa depois da instalação.

```bash
Rscript -e '
install.packages("pak", repos = "https://cloud.r-project.org")
pak::pkg_install(c(
  "R6@2.6.1", "yaml@2.3.12", "jsonlite@2.0.0", "httr2@1.3.0",
  "DBI@1.3.0", "RSQLite@3.53.3", "digest@0.6.39",
  "testthat@3.3.2", "cyclocomp@1.1.1"
))
'
```

É necessário ter acesso ao CRAN durante a instalação. Em Linux, o sistema pode
precisar de bibliotecas de desenvolvimento para compilar pacotes, como libcurl,
OpenSSL e libuv. O programa verifica a versão mínima do R e informa dependências
ausentes; consulte esta lista para instalá-las.

Configure os tokens em `.env`, a partir de `.env.example`, ou nas variáveis
`GITHUB_TOKEN` e `HF_TOKEN`. O arquivo existente `.env` foi preservado. Tokens
não são incluídos nos registros de requisições, nos manifestos ou no site.
Coletas anônimas são possíveis, sujeitas às cotas do serviço.

## Execução

A entrada pública é `main.R`; sem argumentos, ela mostra a ajuda. O arquivo
`scripts/internal.R` fica reservado para tarefas da CI e para a preparação do
site pelo Quarto.

| Modalidade | Comando | Efeito |
|---|---|---|
| Piloto | `Rscript main.R --pilot` | Coleta limitada das duas plataformas em banco próprio, sem gerar o site |
| GitHub | `Rscript main.R --github` | Renova os dados GitHub, preservando Hugging Face, e gera o site |
| Hugging Face | `Rscript main.R --huggingface` | Renova os dados Hugging Face, preservando GitHub, e gera o site |
| Análise | `Rscript main.R --analyze` | Verifica as coletas, processa arquivos de análise disponíveis, exporta resultados e gera o site |
| Completa | `Rscript main.R --run` | Coleta ambas, analisa, promove o banco temporário e gera o site |

`--run` executa a coleta completa. O piloto não gera o site;
coletas GitHub e Hugging Face, `--run` e `--analyze` geram o site ao concluir.
Execute uma modalidade por vez.

As coletas individuais podem ocorrer em qualquer ordem. Somente uma modalidade
é aceita por execução. A configuração usada é `config/settings.yml`. Cada nova
coleta começa novamente sua plataforma. Não há retomada automática a partir de
dados parciais.

Ajuda e prévia local:

```bash
Rscript main.R --help
quarto preview
```

O site é uma apresentação estática dos artefatos locais; o Quarto não consulta
APIs. Os testes automatizados são executados pela CI.

## Organização

```text
main.R
config/
  settings.yml                protocolo, vocabulários de IA/ML e limites
  osi-licenses.json           snapshot SPDX com identificadores aprovados OSI
  privacy-concepts.yml        20 conceitos; variantes e fontes separadas
  taxonomy.yml                24 categorias do codebook
src/
  bootstrap.R                 carregamento das classes e dependências
  app/                        CLI, composição e execução dos testes
  clients/
    HttpClient.R              transporte, timeout, intervalos e cotas
    Pagination.R              paginação compartilhada e callbacks
    github/                   cliente GitHub e busca particionada
    huggingface/              cliente Hugging Face
  collection/
    github/                   coletor de issues e comentários
    huggingface/              coletor de Discussions e eventos
  config/                     configuração e integridade do protocolo
  domain/                     datas, licenças e confirmação textual
  selection/                  elegibilidade e confirmação de IA/ML
  storage/                    SQLite, auditoria, lock e fonte persistente do site
  data/                       população e textos para avaliação
  analysis/                   validação, amostragem e processamento analítico
  reporting/                  exportação e site
inputs/
  data/                       SQLite oficial, diário de coletas e archive/
    pilot/                    SQLite e resumo da última tentativa do piloto
  raw/                        respostas das APIs por execução
    pilot/                    respostas apenas da última tentativa do piloto
  final/
    collection/               CSV e manifesto preparados para análise
    archive/                  versões anteriores dos arquivos preparados
  reference/                  bibliografia e dados do pacote de replicação
outputs/                      figuras, tabelas, relatórios e metadados de saída
site/                         template, idiomas, tema e registro da fonte selecionada
_site/                        site Quarto gerado localmente, ignorado pelo Git
tests/                        contratos e transporte simulado
scripts/internal.R            tarefas internas da CI e do Quarto
```

Os objetos R6 têm estrutura bloqueada. Os contratos verificam uma classe por
arquivo, até oito parâmetros por construtor e complexidade ciclomática máxima
de 15 por método de produção. Carregar um arquivo de classe não executa seu
fluxo. Dependências e transporte são compostos explicitamente e podem ser
substituídos nos testes.

## Protocolo

O corte inclusivo dos conteúdos é **22/09/2026, em UTC**, nas duas plataformas.
O corte histórico de 30/06/2024 pertence ao artigo-base. Datas ausentes ou
inválidas de Issues, Discussions, comentários e eventos não comprovam
elegibilidade. A data de criação do repositório não é critério; o corte se aplica
ao conteúdo analisado. A janela das discussões começa em 14/04/2016 para
GDPR, 28/06/2018 para CCPA, 03/11/2020 para CPRA e 23/05/2018 para Data
Protection Act. Comentários e eventos posteriores ao corte são descartados.

São exatamente sete termos legais, configurados em `settings.yml`. Os nomes
das leis são procurados literalmente, ignorando caixa, inclusive dentro de
palavras maiores. Uma discussão pode ter várias leis e vários termos.
Palavras-chave de conceitos e sinais GitHub de IA/ML respeitam limites de palavra.

Projetos precisam ser disponíveis e públicos, ter licença SPDX aprovada na
lista OSI local e evidência suficiente de IA/ML. Todo
identificador de licença em uma expressão precisa ser aprovado. Identificadores
`LicenseRef`, licença ausente e licença desconhecida impedem inclusão. Operadores
AND/OR, parênteses e exceções SPDX reconhecidas são validados. Aliases com caixa
minúscula do Hugging Face são normalizados para os identificadores locais.
Forks e arquivos arquivados são aceitos. Não há filtros por estrelas, downloads,
tamanho, idioma ou popularidade.

No GitHub, a descoberta procura termos legais globalmente em issues públicas e
fechadas. A issue não precisa mencionar IA. Autores de issues identificados como
bots são excluídos; comentários de bots podem conter evidências. Pull requests e
commits ficam fora. Uma menção de busca não confirmada após coleta completa de
comentários é um problema pendente. Quando todas as menções encontradas estão
em comentários comprovadamente posteriores ao corte, registra uma exclusão
temporal resolvida, sem tornar a coleta incompleta. Comentários faltantes e
menções com datas desconhecidas continuam sendo problemas pendentes.

O escopo GitHub de IA/ML exige simultaneamente sinal de descoberta e evidência
técnica em dependências ou código, ou produção e consumo de modelos. O coletor
atual fornece manifestos da raiz e README condicional; não percorre subdiretórios
ou código. O classificador aceita código quando fornecido explicitamente. Os 24
tópicos foram mantidos exatamente como enviados pelo usuário. Os vocabulários
complementares estão explicitados na configuração e precisam de validação no
contexto da pesquisa.

No Hugging Face, modelos, datasets e Kernels são descobertos por licença OSI,
com paginação processada por callbacks e deduplicação por tipo e identificador.
Spaces usam a listagem geral paginada: a API documenta `filter` como filtro por
tags e não oferece filtro por licença nesse endpoint. A licença de cada Space
é validada localmente pelos metadados, tags e README; por isso, o limite de
1.000 Spaces descobertos pode resultar em menos de 1.000 elegíveis. Buckets
ficam fora da coleta porque não são unidades com Discussions. Spaces com acesso
gated são excluídos. Kernels usam metadados próprios; `KernelInfo` não documenta
campos como `createdAt` ou `disabled`. A documentação oficial sobre
[repositórios Kernel](https://huggingface.co/docs/huggingface_hub/en/guides/repository)
lista métodos de consulta de um Kernel, arquivos e referências, mas não documenta uma listagem geral de Kernels. A
descoberta implementada usa `/api/kernels` como rota exploratória; sua paginação
e cobertura precisam ser validadas contra respostas reais antes de uma coleta
ser considerada integral para esse tipo. O código consulta apenas os campos
disponíveis para cada tipo e usa o README do repositório quando precisa
confirmar licença ou finalidade de IA/ML. Tarefa, pipeline ou biblioteca reconhecida em metadados estruturados confirma IA/ML;
SDK de interface ou tags genéricas isoladas não confirmam. Issues e Discussions
seguem o corte temporal; a data de criação do repositório não substitui a data
do conteúdo. Apenas Discussions fechadas são aceitas; pull requests e autores
identificados como bots são excluídos. Estado, autoria, data e tipo são
verificados na listagem e novamente nos detalhes. Comentários de bots em
discussões elegíveis são preservados. A identificação
de bots usa o tipo da conta, padrões de nome e `eligibility.hf_bot_accounts`,
que inclui `parquet-converter`. Eventos textuais são tratados individualmente;
pull requests e commits ficam fora. A indexação de licenças do serviço limita
a descoberta de modelos, datasets e Kernels. Consulte a documentação oficial de
[HfApi](https://huggingface.co/docs/huggingface_hub/en/package_reference/hf_api),
[cartões de Spaces](https://huggingface.co/docs/huggingface_hub/main/en/package_reference/cards)
e [Discussions](https://huggingface.co/docs/huggingface_hub/en/guides/community).

O protocolo é `1.3.0`, registrando a inclusão de Kernels, a decisão automática
sem fila de revisão de repositórios e distinguindo estas
regras das coletas anteriores. Os dados
do piloto já existente continuam com o protocolo usado em sua execução; testes
offline não substituem nem reclassificam esse banco.

Os conteúdos refletem o momento da coleta, incluindo possíveis edições
posteriores ao corte; o programa não reconstrói integralmente o estado histórico.

## Auditoria e resultados

- `inputs/data/research.sqlite`: banco científico publicado após sucesso.
- `inputs/data/archive/`: versões anteriores dos bancos científicos e snapshot fixo da fonte do site.
- `inputs/data/latest-collections.json`: última tentativa de cada plataforma científica.
- `inputs/data/pilot/pilot.sqlite` e `summary.json`: banco e contagens do último piloto.
- `inputs/raw/<execução>/<sha256>.body`: bytes das respostas científicas e integridade.
- `inputs/raw/pilot/<execução>/<sha256>.body`: respostas apenas do último piloto.
- `inputs/final/collection/`: população, amostra, estratos, codebook e manifesto.
- `inputs/final/archive/`: versões anteriores dos arquivos preparados para análise.
- `_site/`: site estático Quarto gerado localmente.
- `site/collection-source.json`: fonte selecionada e registro da transição.
- `site/pilot-summary.json`: procedência e cobertura do piloto usados no site antes da transição.

Os dados produzidos pela coleta ficam em `inputs`, pois serão a entrada das
análises posteriores. `outputs/figures`, `outputs/tables` e `outputs/reports`
ficam disponíveis para os resultados dessas análises.

Cada novo piloto apaga suas subpastas `inputs/data/pilot` e `inputs/raw/pilot`
antes da coleta. Apenas a última tentativa é mantida, mesmo quando falha:
o banco de diagnóstico fica em `inputs/data/pilot` até o próximo piloto.
O piloto não arquiva bancos e não altera dados científicos, referências ou
planilhas manuais. As coletas científicas mantêm bancos anteriores e respostas
brutas por execução; novas exportações preservam os CSV anteriores em `archive/`.

O site usa o piloto existente como prévia preliminar até um `--run` concluir as
duas plataformas sem limites do piloto e com paginação e cobertura verificadas.
Nesse momento, `site/collection-source.json` registra a transição permanente e
um snapshot imutável é guardado em `inputs/data/archive/site-source/`, fora das
pastas que o piloto limpa. Pilotos posteriores não alteram essa escolha. Toda
rota de geração, inclusive o pre-render do Quarto e a publicação em CI, falha
com uma mensagem explícita se o snapshot ou as respostas brutas necessárias
estiverem indisponíveis; não retorna aos dados do piloto. Para gerar o site a
partir de um checkout limpo após essa transição, os arquivos apontados pelo
registro oficial precisam estar disponíveis nesse checkout.

SQLite preserva projetos, artefatos, evidências, execuções, tentativas, respostas,
problemas e indisponibilidades reconhecidas. Evidências legais, de conceitos e
de IA/ML registram termos, origem, trechos e versão da regra. As identidades
distinguem plataforma, tipo e identificador, incluindo comentários e eventos.
As contagens de ocorrências, discussões e repositórios não são intercambiáveis.
O total GitHub descreve repositórios encontrados por buscas de discussões sobre
legislação, sem representar todos os repositórios de IA/ML da plataforma.

A análise exige as duas últimas tentativas científicas concluídas, sem problemas
pendentes, com o corte, versão e fingerprint esperados, além da integridade das
respostas brutas. Uma tentativa falha torna a análise pendente mesmo quando o
banco anterior continua preservado. Bancos temporários com falhas permanecem
no diretório do banco com sufixo `-failed.sqlite`, para diagnóstico.

Coletas individuais também usam banco temporário, renovando somente sua
plataforma. A modalidade completa só promove o banco após sucesso das duas
coletas e da análise. Há um lock contra execuções concorrentes. Depois de uma
interrupção abrupta, confira o PID em `.run-lock/pid` antes de remover
manualmente um lock deixado por processo já encerrado.

Uma falha de renderização é registrada em `outputs/metadata/site-failure.txt` e
reportada separadamente da conclusão da coleta. O site mostra resultados
pendentes quando faltam coletas ou análise compatível.

## Amostragem

Unidades: issues GitHub e Discussions Hugging Face com evidência legal, em
projetos elegíveis. Estratos: plataforma × tipo de repositório × lei.

```text
z = qnorm(0.995)
n0 = z² × 0.5 × (1 − 0.5) / 0.05²
n = min(N, ceiling(n0 / (1 + (n0 − 1) / N)))
```

Os estratos e unidades são ordenados antes do sorteio. A semente é 20260920
mais o índice do estrato, começando em 1. A amostragem é sem reposição. Os
arquivos preparados são gravados em `inputs/final/collection/`.

## Comunicação e limites do piloto

Páginas de 100 registros não impõem limite à população científica. A busca
GitHub é subdividida por criação quando supera 1.000 resultados ou apresenta
resultados incompletos, até segundos. Saturação no mesmo segundo, cursores
inválidos ou repetidos e falhas de paginação são registrados.

Timeout por requisição: 30 segundos. Até cinco tentativas de falhas transitórias
com orçamento de 180 segundos. Buscas GitHub: intervalo mínimo de 2,2 segundos;
esperas de cota com orçamento de seis horas contado desde a primeira espera.
Hugging Face: 0,32 segundo para API, 0,11 para resolução e 1,6 para páginas;
até cinco repetições de cota por chamada com orçamento de 30 minutos. Cabeçalhos
de renovação são respeitados; fallback cresce de 30 a 300 segundos.

| Limite exclusivo do piloto | Quantidade |
|---|---:|
| Resultados GitHub examinados por termo | 600 |
| Repositórios GitHub validados | 600 |
| Issues de projetos GitHub aceitos processadas | 100 |
| Comentários por issue | 20 |
| Repositórios HF descobertos por tipo | 1000 |
| Repositórios HF elegíveis processados por tipo | 1000 |
| Entradas de discussão examinadas por repositório HF | 20 |

O limite do piloto do Hugging Face é de até 4.000 repositórios catalogados:
1.000 por tipo entre modelos, datasets, Spaces e Kernels. Filtros podem reduzir
as quantidades elegíveis. O piloto não estima cobertura, tempo ou consumo de
cota da coleta completa.

## Referências

A bibliografia, os DOIs e os papéis das fontes estão em
[`inputs/reference/literature_methods.md`](inputs/reference/literature_methods.md).
O código do outro projeto do usuário não foi utilizado como referência de
implementação. Os dados do pacote científico foram preservados com commit de
origem e hashes. As 20 listas originais e as 14 revisões disponíveis mantêm sua
procedência. A taxonomia segue as 24 categorias do codebook HTML preservado.

## Site e GitHub Pages

```bash
quarto render
```

A saída é `_site/index.html`, ignorada pelo Git. `_site` é o diretório padrão
de saída de websites Quarto; o GitHub Pages recebe seu conteúdo pelo artefato
do workflow, sem precisar versionar os arquivos gerados. Veja a
[documentação do Quarto](https://quarto.org/docs/publishing/github-pages.html#ignoring-output).
O site mantém os estilos e recursos visuais
pré-configurados e oferece controles de tema e tradução dos textos do protocolo.
O workflow `.github/workflows/check.yml` executa os testes em pull requests e
em cada push para `main`. Quando os testes de um push em `main` passam, o
workflow `.github/workflows/quarto-publish.yml` renderiza e publica o site em
uma execução separada; assim, os testes não são repetidos durante a publicação.
A publicação também pode ser acionada manualmente. Configure Pages para usar
GitHub Actions. O workflow publica a única página metodológica; dados científicos
locais não são enviados automaticamente, pois bancos, respostas brutas e CSV
preparados são ignorados pelo Git.

`site/` guarda o template e os recursos de origem; `_site/` é o pacote gerado
para publicação. As regras de inclusão do Quarto estão restritas à raiz do
projeto, evitando copiar recursos de antigas pastas de saída.

Figuras e imagens de tabelas continuam sendo produzidas em `outputs/figures`
e `outputs/tables`. Referencie os arquivos no template da página, por exemplo:

```markdown
![Figura](/outputs/figures/nome-da-figura.png)
![Tabela](/outputs/tables/nome-da-tabela.png)
```

O Quarto copia para `_site` as imagens usadas pela página, mantendo seus caminhos
para que funcionem também no GitHub Pages. A origem permanece em `outputs`;
arquivos sem referência na página não são incluídos automaticamente.

Nenhum comando do projeto cria commits, faz push ou publica automaticamente.
O resumo do piloto mais recente fica em `inputs/data/pilot/summary.json`, arquivo
local ignorado pelo Git e substituído no próximo piloto. A população científica
completa ainda não foi coletada.
