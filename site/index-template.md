---
title: "Discussões sobre privacidade em OSS de IA/ML"
subtitle: "GitHub e Hugging Face"
---

<div class="hero-note"><p data-i18n="intro">Identificação de menções à legislação de privacidade em issues do GitHub e Discussions dos repositórios do Hugging Face.</p></div>

## Estado do projeto {#visao-geral}

<p id="collection-status" role="status">{{STATUS}}</p>
<div id="source-provenance">{{PROVENANCE}}</div>

<div class="metric-grid">
<div class="metric-card"><h3>{{CATALOGUED}}</h3><p data-i18n="catalogued">Repositórios catalogados</p></div>
<div class="metric-card"><h3>{{ELIGIBLE}}</h3><p data-i18n="eligible">Repositórios elegíveis</p></div>
<div class="metric-card"><h3>{{REPOSITORIES_WITH_EVIDENCE}}</h3><p data-i18n="repositories_with_evidence">Repositórios com menções a leis</p></div>
</div>

<p data-i18n="pending">Um traço indica resultado pendente. Dados de piloto são prévias limitadas, identificadas como preliminares, e não são resultados científicos.</p>

## Método {#metodologia}

<p data-i18n="method">A descoberta precede a seleção dos repositórios. A confirmação registra ocorrências textuais e sua procedência; as categorias seguem o codebook do estudo.</p>

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

<p data-i18n="hf">Hugging Face: descoberta de modelos, datasets, Spaces e Kernels por cada licença OSI; Buckets ficam fora da coleta porque não são unidades com Discussions. Os campos variam por tipo: a listagem de Spaces pode omitir gated, então o coletor consulta os detalhes. Como esse campo é opcional, valor ausente ou nulo significa não gated; valores auto, manual ou inválidos são excluídos. Kernels têm metadados próprios. A rota de listagem de Kernels usada pelo coletor não está entre os métodos gerais oficialmente documentados; sua paginação e cobertura precisam de validação ao vivo antes de essa parte ser considerada integral. Metadados e README confirmam licença e finalidade IA/ML. Apenas Discussions fechadas são aceitas; pull requests e discussões iniciadas por bots são excluídos. Comentários de bots em discussões elegíveis são preservados.</p>

<p data-i18n="licenses">Ambas as plataformas: licença SPDX reconhecida pela lista OSI local. O corte temporal se aplica à criação de Issues e Discussions, não à criação do repositório. Todos os identificadores em expressões de licença precisam ser aprovados. Forks e repositórios arquivados são aceitos; não há limiares de popularidade.</p>

<p data-i18n="concepts">20 conceitos: listas originais e revisadas do pacote científico, com limites de palavra e procedência separada. 24 categorias definidas no codebook, sem classificação automática por palavras-chave.</p>

## Amostra {#dados}

<p data-i18n="sampling">Estratos: plataforma × tipo de repositório × lei. Cochran com correção para população finita: confiança de 99%, margem de 5%, proporção de 50%; tamanho arredondado para cima e limitado à população. Sorteio sem reposição, semente 20260920 acrescida do índice do estrato.</p>

<p data-i18n="exports">Os CSV de população, amostra, estratos, codificação e codebook, além do manifesto com hashes, ficam em inputs/final/collection para as análises posteriores. Os dados brutos e tokens não são copiados para o site.</p>

## Execução local {#reproducao}

```bash
Rscript main.R --help
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

<p data-i18n="limits">Menção textual não decide conformidade ou violação legal. O total de repositórios GitHub corresponde aos encontrados nas buscas de discussões sobre legislação, sem estimar todos os repositórios de IA/ML da plataforma. A descoberta no Hugging Face depende da indexação de licenças. O piloto demonstra funcionamento em um recorte limitado; cobertura, tempo e consumo de cota da coleta completa exigem validação.</p>

<p data-i18n="unfinished">A precisão da seleção de IA/ML e a cobertura das licenças ainda precisam de validação empírica.</p>

## Referências {#referencias-metodologicas}

{{REFERENCES}}
