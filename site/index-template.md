---
title: "Discussões sobre privacidade em OSS de IA/ML"
subtitle: "GitHub e Hugging Face · coleta auditável e avaliação humana"
---

<div class="hero-note"><p data-i18n="intro">Identificação de menções à legislação de privacidade em issues do GitHub e Discussions de modelos e datasets do Hugging Face.</p></div>

## Estado do projeto {#visao-geral}

<p id="collection-status" role="status">{{STATUS}}</p>

<div class="metric-grid">
<div class="metric-card"><h3>{{CATALOGUED}}</h3><p data-i18n="catalogued">Projetos catalogados</p></div>
<div class="metric-card"><h3>{{ELIGIBLE}}</h3><p data-i18n="eligible">Projetos elegíveis</p></div>
<div class="metric-card"><h3>{{DISCUSSIONS}}</h3><p data-i18n="discussions">Discussões únicas com evidência legal</p></div>
</div>

<p data-i18n="pending">Um traço indica resultado pendente. Pilotos e testes simulados não compõem os resultados científicos.</p>

## Método {#metodologia}

<p data-i18n="method">A descoberta precede a seleção dos projetos. A confirmação registra ocorrências textuais e sua procedência; as categorias de privacidade são atribuídas pelos avaliadores.</p>

| Questão | Objeto |
|---|---|
| RQ1 | Direitos dos titulares e princípios mencionados; título/texto inicial separados do contexto dos comentários |
| RQ2 | Preocupações discutidas e cobertura pela taxonomia original de 24 categorias |
| RQ3 | Etapas do desenvolvimento de IA/ML/LLM às quais as preocupações se referem |

<p data-i18n="rq_scope">GitHub × Hugging Face integra as três RQs. A comparação com OSS em geral integra RQ1 e RQ2. Não há RQ4 nem comparação antes/depois da GDPR. Comentários automatizados em discussões humanas são preservados como contexto.</p>

| Lei | Termos literais | Início da janela |
|---|---|---|
| GDPR | GDPR; General Data Protection Regulation | 14/04/2016 |
| CCPA | CCPA; California Consumer Privacy Act | 28/06/2018 |
| CPRA | CPRA; California Privacy Rights Act | 03/11/2020 |
| Data Protection Act | Data Protection Act | 23/05/2018 |

<p data-i18n="cutoff">Corte inclusivo: 22/09/2026, em UTC. Datas ausentes ou inválidas não comprovam elegibilidade. Conteúdos editados depois do corte podem estar presentes nos textos atuais.</p>

<p data-i18n="github">GitHub: busca global de termos legais em issues públicas e fechadas; exclui pull requests e autores de issues identificados como bots. O repositório precisa de um sinal de descoberta de IA/ML e evidência técnica. A coleta lê manifestos na raiz e README quando necessário; não percorre código-fonte ou subdiretórios.</p>

<p data-i18n="hf">Hugging Face: descoberta de modelos e datasets por cada licença OSI; exclui Spaces, projetos privados e acesso gated. Uma tarefa, pipeline ou biblioteca reconhecida em metadados estruturados confirma IA/ML. Apenas Discussions fechadas são aceitas; autores identificados como bots são excluídos.</p>

<p data-i18n="licenses">Ambas as plataformas: licença SPDX reconhecida pela lista OSI local e criação até o corte. Todos os identificadores em expressões de licença precisam ser aprovados. Forks e projetos arquivados são aceitos; não há limiares de popularidade.</p>

<p data-i18n="concepts">20 conceitos: listas originais e revisadas do pacote científico, com limites de palavra e procedência separada. 24 categorias: codebook humano, sem classificação automática por palavras-chave.</p>

## Amostra e avaliação {#dados}

<p data-i18n="sampling">Estratos: plataforma × tipo de repositório × lei. Cochran com correção para população finita: confiança de 99%, margem de 5%, proporção de 50%; tamanho arredondado para cima e limitado à população. Sorteio sem reposição, semente 20260920 acrescida do índice do estrato.</p>

<p data-i18n="coding">Cada discussão aparece uma vez por avaliador na planilha CSV, mesmo quando participa de várias leis. Dois avaliadores por padrão. Relevância: 0, 1 ou vazio. Categorias: IDs do codebook separados por ponto e vírgula, sem repetição. Kappa usa apenas pares preenchidos; casos sem pares ou com concordância esperada igual a 1 permanecem indefinidos.</p>

<p data-i18n="exports">Os CSV de população, amostra, estratos, codificação e codebook, além do manifesto com hashes, ficam em inputs/final/collection para as análises posteriores. Os dados brutos e tokens não são copiados para o site.</p>

## Etapas do desenvolvimento — RQ3 {#rq3}

<p id="rq3-status" role="status">{{RQ3_STATUS}}</p>

<p data-i18n="rq3_instrument">Instrumento ml-stages-1.0.0: requisitos do modelo, coleta de dados, limpeza, rotulagem, engenharia de características, treinamento, avaliação, implantação e monitoramento. Eixo separado das 24 categorias, inspirado em Amershi et al. (2019). As definições operacionais e adaptações para LLM são desta pesquisa; etapas não são inferidas pelo hub.</p>

<p data-i18n="rq3_review">Dois avaliadores cobrem toda a amostra independentemente; o consenso é preservado em outra planilha. Cada etapa identificada exige trecho e artefato de origem. Pendência difere de etapa indeterminada após avaliação. A concordância por etapa é calculada antes do consenso; pares indeterminados ou não relevantes não são tratados como ausência da etapa.</p>

{{RQ3_RESULTS}}

<p data-i18n="rq3_denominator">Descrições da amostra manual, sem extrapolação para a população: N é o número de discussões relevantes com anotação de etapa concluída, incluindo indeterminadas. Pendências ficam separadas. Uma discussão pode ter várias etapas e as proporções podem somar mais de 100%. Denominador zero produz proporção indefinida; zero discussões relevantes no HF é um resultado válido.</p>

<p data-i18n="rq3_inference">Para cada uma das nove etapas: H0, a proporção em discussões relevantes é igual entre os hubs; H1, difere. Contrastes exigem projetos comparáveis, tratamento do agrupamento por projeto e vínculos entre hubs, efeitos, intervalos e ajuste de Holm. Enquanto faltarem esses requisitos, são registrados como não testáveis. Diferenças não demonstram conformidade nem maior preocupação jurídica de um hub.</p>

## Execução local {#reproducao}

```bash
Rscript main.R --check
Rscript main.R --test
Rscript main.R --pilot
Rscript main.R --github
Rscript main.R --huggingface
Rscript main.R --analyze
```

<p data-i18n="full">A opção --run faz as duas coletas e a análise usando banco temporário. O banco oficial só é substituído após sucesso, com arquivamento do anterior. A análise verifica as duas últimas tentativas, os problemas pendentes, o corte, as versões e os hashes das respostas brutas.</p>

```bash
Rscript main.R --run
quarto preview
```

<p data-i18n="publication">O site está preparado para GitHub Pages. O workflow de publicação é manual. Testar ou renderizar localmente não cria commits nem publica o projeto.</p>

<p>O piloto não gera o site. As coletas GitHub e Hugging Face, a análise e a execução completa geram a página automaticamente ao concluir.</p>

## Limites {#limites}

<p data-i18n="limits">Menção textual não decide conformidade ou violação legal. O total de projetos GitHub corresponde aos encontrados nas buscas de discussões legais, sem estimar todos os projetos de IA/ML da plataforma. A descoberta no Hugging Face depende da indexação de licenças. O piloto demonstra funcionamento em um recorte limitado; cobertura, tempo e consumo de cota da coleta completa exigem validação.</p>

<p data-i18n="unfinished">BERT, avaliação humana e todas as análises da dissertação não são executados automaticamente. A precisão da seleção de IA/ML e a cobertura das licenças ainda precisam de validação empírica.</p>

## Referências {#referencias-metodologicas}

{{REFERENCES}}
