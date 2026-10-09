# Legislação de privacidade em projetos Open Source de IA/ML

Projeto em **R com R6** para identificar menções a GDPR, CCPA, CPRA e Data
Protection Act em issues do GitHub e Discussions de modelos e datasets do
Hugging Face. Preserva as respostas da coleta, confirma menções textuais e
prepara uma amostra estratificada para avaliação humana.
Integra uma classificação humana independente por etapas de desenvolvimento
de IA/ML/LLM para a RQ3, com evidências, consenso e descrições por hub.

Uma menção não estabelece conformidade ou violação legal. O projeto não executa
BERT, não realiza a avaliação humana e não implementa todas as análises da
dissertação. A precisão da identificação de IA/ML e a cobertura da descoberta
por licença precisam de validação empírica.

Projetos com status `review` ficam no catálogo, fora da população elegível;
ainda não há importação de decisões humanas nem reprocessamento desses casos.
Os conceitos são registrados nas unidades principais, comentários e eventos,
com origem identificável. As exportações separam título/texto inicial do
contexto dos comentários para RQ1, sinalizando texto inicial HF não comprovado.
Há kappa de relevância e por etapa, antes do consenso; a concordância das
24 categorias e as outras análises da dissertação permanecem fora desta alteração.

RQ1 trata dos direitos e princípios mencionados; RQ2, das preocupações e da
cobertura da taxonomia original; RQ3, das etapas às quais as preocupações se
referem. GitHub × Hugging Face integra as três RQs. A comparação com OSS em
geral integra RQ1 e RQ2. Não há RQ4 ou experimento antes/depois da GDPR.

## Requisitos e instalação

R ≥ 4.6.0 e Quarto no PATH. O lockfile foi gerado com R 4.6.1, versão usada na
CI. Não é necessário usar RStudio ou um arquivo `.Rproj`.
Pacotes de produção: `R6`, `yaml`, `jsonlite`, `httr2`, `DBI`, `RSQLite`, `digest`.
Os testes usam `testthat` e `cyclocomp`.

A execução exige R 4.6.0 ou superior antes de carregar dependências, instalar
pacotes ou iniciar qualquer modalidade. Versões anteriores são recusadas com
uma mensagem que identifica a versão instalada.

```bash
Rscript main.R --install
Rscript main.R --mode check
Rscript main.R --mode test
```

`--install` restaura as versões registradas em `renv.lock` para a biblioteca
isolada do projeto. A primeira restauração requer acesso ao CRAN. Sistemas Linux
podem precisar dos pacotes de desenvolvimento de libcurl e OpenSSL para compilar
dependências. A instalação não inicia uma coleta.

Configure os tokens em `.env`, a partir de `.env.example`, ou nas variáveis
`GITHUB_TOKEN` e `HF_TOKEN`. O arquivo existente `.env` foi preservado. Tokens
não são incluídos nos registros de requisições, nos manifestos ou no site.
Coletas anônimas são possíveis, sujeitas às cotas do serviço.

## Execução

`main.R` é a única entrada procedural. Classes de produção e de testes têm um
arquivo próprio. Sem argumentos, o programa mostra a ajuda.

| Modalidade | Comando | Efeito |
|---|---|---|
| Piloto | `Rscript main.R --mode pilot` | Coleta limitada das duas plataformas em banco próprio, sem gerar o site |
| GitHub | `Rscript main.R --mode github` | Renova os dados GitHub, preservando Hugging Face, e gera o site |
| Hugging Face | `Rscript main.R --mode huggingface` | Renova os dados Hugging Face, preservando GitHub, e gera o site |
| Análise | `Rscript main.R --mode analyze` | Verifica as coletas, exporta a amostra e gera o site |
| Completa | `Rscript main.R --run` | Coleta ambas, analisa, promove o banco temporário e gera o site |

As opções diretas são equivalentes e podem ser usadas como entrada principal:

```bash
Rscript main.R --pilot
Rscript main.R --github
Rscript main.R --huggingface
Rscript main.R --analyze
Rscript main.R --run
```

`--run` (ou `--mode run`) executa a coleta completa. O piloto não gera o site;
coletas GitHub e Hugging Face, `--run` e `--analyze` geram o site ao concluir.
Não combine duas modalidades no mesmo comando.

As coletas individuais podem ocorrer em qualquer ordem. Somente uma modalidade
é aceita por execução. `--config caminho.yml` seleciona a configuração. Cada
nova coleta começa novamente sua plataforma. Não há retomada automática a partir
de dados parciais.

Comandos de apoio:

```bash
Rscript main.R --help
Rscript main.R --mode check
Rscript main.R --mode test
Rscript main.R --mode site
quarto preview
```

`prepare-site` é usado internamente pelo pre-render do Quarto. O site é uma
apresentação estática dos artefatos locais; o Quarto não consulta APIs.

## Organização

```text
main.R
config/
  settings.yml                protocolo, vocabulários de IA/ML e limites
  osi-licenses.json           snapshot SPDX com identificadores aprovados OSI
  privacy-concepts.yml        20 conceitos; variantes e fontes separadas
  taxonomy.yml                24 categorias do codebook humano
  development-stages.yml      instrumento próprio e versionado para RQ3
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
  storage/                    SQLite, auditoria, lock e promoção de banco
  data/                       população e textos para avaliação
  analysis/                   validação, amostragem, concordância e descrição RQ3
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
  tables/rq3/                 frequências, concordância, relações, exemplos e contrastes
  reports/rq3.json            estado da avaliação e integridade dos resultados
site/                         template, estilos, idioma e tema
_site/                        site Quarto gerado localmente, ignorado pelo Git
tests/                        contratos e transporte simulado
```

Os objetos R6 têm estrutura bloqueada. Os contratos verificam uma classe por
arquivo, até oito parâmetros por construtor e complexidade ciclomática máxima
de 15 por método de produção. Carregar um arquivo de classe não executa seu
fluxo. Dependências e transporte são compostos explicitamente e podem ser
substituídos nos testes.

## Protocolo

O corte inclusivo é **22/09/2026, em UTC**, nas duas plataformas. O corte
histórico de 30/06/2024 pertence ao artigo-base. Datas ausentes ou inválidas não
comprovam elegibilidade. A janela das discussões começa em 14/04/2016 para
GDPR, 28/06/2018 para CCPA, 03/11/2020 para CPRA e 23/05/2018 para Data
Protection Act. Comentários e eventos posteriores ao corte são descartados.

São exatamente sete termos legais, configurados em `settings.yml`. Os nomes
das leis são procurados literalmente, ignorando caixa, inclusive dentro de
palavras maiores. Uma discussão pode ter várias leis e vários termos.
Palavras-chave de conceitos e sinais GitHub de IA/ML respeitam limites de palavra.

Projetos precisam ser disponíveis, públicos, criados até o corte, ter licença
SPDX aprovada na lista OSI local e evidência suficiente de IA/ML. Todo
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

No Hugging Face, a descoberta percorre cada licença OSI para modelos e datasets,
com paginação processada por callbacks e deduplicação por tipo e identificador.
Spaces, recursos privados, desativados e `gated` são excluídos. Metadados são
complementados por consulta de detalhes e pelo cabeçalho YAML do card. Tarefa,
pipeline ou biblioteca reconhecida em campos estruturados confirmam IA/ML;
tags genéricas isoladas não confirmam. Apenas Discussions fechadas são aceitas;
autores identificados como bots são excluídos. Estado, autoria, data e tipo são
verificados na listagem e novamente nos detalhes. A identificação de bots usa
o tipo da conta, os padrões de nome e `eligibility.hf_bot_accounts`, que inclui
`parquet-converter`. Eventos textuais são tratados individualmente; pull requests
e commits ficam fora. A indexação de licenças do serviço limita a descoberta.

O protocolo é `1.1.0`, distinguindo essas regras das coletas anteriores. Os dados
do piloto já existente continuam com o protocolo usado em sua execução; testes
offline não substituem nem reclassificam esse banco.

Os conteúdos refletem o momento da coleta, incluindo possíveis edições
posteriores ao corte; o programa não reconstrói integralmente o estado histórico.

## Auditoria e resultados

- `inputs/data/research.sqlite`: banco científico publicado após sucesso.
- `inputs/data/archive/`: versões anteriores dos bancos científicos.
- `inputs/data/latest-collections.json`: última tentativa de cada plataforma científica.
- `inputs/data/pilot/pilot.sqlite` e `summary.json`: banco e contagens do último piloto.
- `inputs/raw/<execução>/<sha256>.body`: bytes das respostas científicas e integridade.
- `inputs/raw/pilot/<execução>/<sha256>.body`: respostas apenas do último piloto.
- `inputs/final/collection/`: população, amostra, estratos, codificações, codebook e manifesto.
- `inputs/final/archive/`: versões anteriores dos arquivos preparados para análise.
- `_site/`: site estático Quarto gerado localmente.

Os dados produzidos pela coleta ficam em `inputs`, pois serão a entrada das
análises posteriores. `outputs/figures`, `outputs/tables` e `outputs/reports`
ficam disponíveis para os resultados dessas análises. Uma planilha preenchida
manualmente, como `inputs/final/coding-reviewed.csv`, permanece fora de
`collection/` e não é substituída pelas exportações.

Cada novo piloto apaga suas subpastas `inputs/data/pilot` e `inputs/raw/pilot`
antes da coleta. Apenas a última tentativa é mantida, mesmo quando falha:
o banco de diagnóstico fica em `inputs/data/pilot` até o próximo piloto.
O piloto não arquiva bancos e não altera dados científicos, referências ou
planilhas manuais. As coletas científicas mantêm bancos anteriores e respostas
brutas por execução; novas exportações preservam os CSV anteriores em `archive/`.

SQLite preserva projetos, artefatos, evidências, execuções, tentativas, respostas,
problemas e indisponibilidades reconhecidas. Evidências legais, de conceitos e
de IA/ML registram termos, origem, trechos e versão da regra. As identidades
distinguem plataforma, tipo e identificador, incluindo comentários e eventos.
As contagens de ocorrências, discussões e projetos não são intercambiáveis.
O total GitHub descreve projetos encontrados por discussões legais, sem
representar todos os projetos de IA/ML da plataforma.

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

## Amostragem e codificação

Unidades: issues GitHub e Discussions Hugging Face com evidência legal, em
projetos elegíveis. Estratos: plataforma × tipo de repositório × lei.

```text
z = qnorm(0.995)
n0 = z² × 0.5 × (1 − 0.5) / 0.05²
n = min(N, ceiling(n0 / (1 + (n0 − 1) / N)))
```

Os estratos e as unidades são ordenados antes do sorteio. A semente é 20260920
mais o índice do estrato, começando em 1. A amostragem é sem reposição. Uma
discussão pode participar de várias leis, mas `coding.csv` reúne cada unidade
uma única vez para cada um dos dois avaliadores configurados.

Preencha `relevance` com `0`, `1` ou vazio; `categories` recebe IDs como
`C01;C02`, sem duplicações. As definições e exemplos estão em `taxonomy.csv`.
Os IDs são locais e estáveis para a versão do codebook preservada. Faça a
avaliação independente em uma cópia da planilha, preservando o template.

```bash
Rscript main.R --mode analyze --coding inputs/final/coding-reviewed.csv
```

Esse comando valida identidade, versão, relevância, categorias e duplicações,
e calcula kappa de **relevância binária** sobre pares preenchidos pelos dois
avaliadores. Sem respostas pareadas ou quando a concordância esperada é 1,
o resultado é indefinido. A avaliação humana não é realizada pelo programa;
sem um arquivo preenchido, o manifesto indica avaliação pendente.

## Instrumento de etapas — RQ3

O [codebook e as instruções](inputs/reference/rq3-codebook.md) definem
`ml-stages-1.0.0`. Os nove IDs `S01`–`S09` constituem um eixo multilabel
separado de `C01`–`C24`, inspirado em
[Amershi et al. (2019)](https://www.microsoft.com/en-us/research/publication/software-engineering-for-machine-learning-a-case-study/).
Definições operacionais, exemplos regulatórios e adaptações para LLM são
nossas. O instrumento está preparado; piloto e validação humana ainda
precisam ocorrer. A coleta permanece no protocolo `1.1.0` e no mesmo
fingerprint; o novo instrumento tem versão e hash próprios.

`--analyze` continua exigindo ambas as últimas coletas científicas válidas.
Além dos arquivos existentes, prepara `development-stages.csv`,
`coding-sources.csv` e `consensus.csv` em `inputs/final/collection/`.
`coding.csv` ganha campos de etapas, versão, hash e evidências, inicialmente
pendentes e sem rótulos ou trechos inventados.

Preserve os templates. Use uma cópia de `coding.csv` para as duas avaliações
independentes de toda a amostra e uma cópia de `consensus.csv` para registrar
o consenso depois dessas avaliações:

```bash
Rscript main.R --analyze --coding inputs/final/coding-reviewed.csv
Rscript main.R --analyze --coding inputs/final/coding-reviewed.csv --consensus inputs/final/consensus-reviewed.csv
```

A importação exige identidade, versão/hash, estado, cobertura e evidência
literal em artefato da mesma discussão. Aceita múltiplas etapas justificadas.
`pending`, `identified`, `indeterminate` e `not_applicable` distinguem
avaliação incompleta, etapas identificadas, indeterminação após avaliação
e discussão não relevante. Indeterminação exige justificativa e não admite
etapas identificadas simultaneamente.

Planilhas antigas sem etapas continuam aceitas para relevância e categorias;
a RQ3 fica pendente. Os arquivos fornecidos não são modificados: seus bytes
são preservados em `independent-input.csv` e `consensus-input.csv` na
exportação, arquivada em uma nova análise. O consenso não substitui nem
entra no cálculo das decisões independentes.

`initial_text`, `comment_context`, `rq1_context_status` e
`coding-sources.csv` distinguem a fonte para RQ1 sem alterar os bancos.
No HF, o primeiro comentário só entra no texto inicial quando tipo, autoria
e data sustentam essa identificação. Caso contrário, `unresolved_context`
sinaliza a necessidade de revisão. Comentários automatizados de discussões
humanas continuam disponíveis.

Os resultados ficam em `outputs/tables/rq3/`:

| Arquivo | Conteúdo |
|---|---|
| `stages.csv` | Contagens, proporções e denominadores por etapa e hub; indeterminadas, pendências e não relevantes separados |
| `agreement.csv` | Acordo bruto e Cohen's kappa por etapa, geral e por hub, com pares e razões de indefinição |
| `stage-categories.csv` | Relações entre etapas e categorias originais, com unidade, projeto e URL |
| `examples.csv` | Trechos, artefatos, papel da fonte, avaliador e versão do consenso |
| `contrasts.csv` | Nove contrastes, H0/H1, diferença descritiva e motivo para não realizar inferência |

As proporções descrevem a amostra manual única, sem pesos ou extrapolação
para a população. O denominador contém relevantes com etapa avaliada,
incluindo indeterminadas; avaliações pendentes são informadas separadamente.
Uma discussão pode entrar em várias etapas, e a soma pode superar 100%.
Denominador zero produz proporção indefinida, não uma coleta inválida.

Kappa por etapa usa pares em que ambos julgaram a discussão relevante e
identificaram etapas. Indeterminadas e não relevantes não viram negativos
artificiais. Pares ausentes e acordo esperado igual a um são explicitamente
indefinidos. A cobertura dos dois avaliadores é exigida no arquivo; linhas
incompletas devem permanecer como pendentes.

Para cada etapa, H0 é igualdade da proporção entre hubs e H1 é diferença.
Inferência exige projetos comparáveis, vínculos entre hubs, agrupamento por
projeto, efeitos, intervalos e ajuste de Holm na família de nove contrastes.
Esses metadados e o desenho não estão estabelecidos no corpus atual: o software
registra `not_testable` e não aplica testes sobre contagens multilabel.
Detalhes estão no codebook. Zero relevantes no HF é um resultado descritivo
válido. Diferenças não medem conformidade ou maior preocupação jurídica.

O site continua com uma página. Exibe RQ3 pendente sem anotações importadas,
rotula resultados parciais como provisórios e verifica versão e integridade
antes de apresentar agregados. Os trechos individuais não vão para a página.

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
| Resultados GitHub examinados por termo | 100 |
| Repositórios GitHub validados | 20 |
| Issues de projetos GitHub aceitos processadas | 100 |
| Comentários por issue | 20 |
| Repositórios HF descobertos por tipo | 50 |
| Repositórios HF elegíveis processados por tipo | 10 |
| Entradas de discussão examinadas por repositório HF | 20 |

Filtros podem reduzir as quantidades elegíveis. O piloto não estima cobertura,
tempo ou consumo de cota da coleta completa.

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
Em 05/10/2026, um piloto real concluiu as duas plataformas sem problemas
pendentes. Suas contagens estão em `inputs/data/pilot/summary.json`, arquivo local
ignorado pelo Git. A população científica completa ainda não foi coletada.
