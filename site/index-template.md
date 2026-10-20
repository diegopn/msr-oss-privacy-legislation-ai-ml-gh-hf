---
title: "Discussões sobre privacidade em OSS de IA/ML"
subtitle: "GitHub e Hugging Face"
---

<div class="hero-note"><p data-i18n="intro">Menções a leis de privacidade em issues do GitHub e Discussions do Hugging Face.</p></div>

## Estado do projeto {#visao-geral}

<p id="collection-status" role="status">{{STATUS}}</p>
<div id="source-provenance">{{PROVENANCE}}</div>

<div class="metric-grid">
<div class="metric-card"><h3>{{CATALOGUED}}</h3><p data-i18n="catalogued">Repositórios catalogados</p></div>
<div class="metric-card"><h3>{{ELIGIBLE}}</h3><p data-i18n="eligible">Repositórios elegíveis</p></div>
<div class="metric-card"><h3>{{REPOSITORIES_WITH_EVIDENCE}}</h3><p data-i18n="repositories_with_evidence">Repositórios com menções a leis</p></div>
</div>

<p data-i18n="pending">Dados de piloto são limitados e preliminares; não representam resultados científicos.</p>

## Método {#metodologia}

| <span data-i18n="rq_heading_question">Questão</span> | <span data-i18n="rq_heading_focus">Foco</span> |
|---|---|
| RQ1 | <span data-i18n="rq1">Direitos e princípios mencionados; texto inicial separado dos comentários</span> |
| RQ2 | <span data-i18n="rq2">Preocupações discutidas e relação com as 24 categorias do estudo-base</span> |
| RQ3 | <span data-i18n="rq3">Nove etapas do desenvolvimento de IA/ML/LLM ligadas às preocupações</span> |

<p data-i18n="rq_scope">GitHub e Hugging Face integram as três questões. A comparação com OSS em geral integra RQ1 e RQ2.</p>

| <span data-i18n="law_heading_law">Lei</span> | <span data-i18n="law_heading_terms">Termos</span> | <span data-i18n="law_heading_start">Início da janela</span> |
|---|---|---|
| GDPR | GDPR; General Data Protection Regulation | 14/04/2016 |
| CCPA | CCPA; California Consumer Privacy Act | 28/06/2018 |
| CPRA | CPRA; California Privacy Rights Act | 03/11/2020 |
| Data Protection Act | Data Protection Act | 23/05/2018 |

<p data-i18n="cutoff">Corte inclusivo dos conteúdos: 22/09/2026 UTC. Datas ausentes ou inválidas não comprovam elegibilidade.</p>

<ul>
<li data-i18n="github">GitHub: busca global por termos legais em issues públicas fechadas; exige sinal de IA/ML e evidência técnica no repositório. Exclui pull requests e autores-bot; comentários de bots podem contar.</li>
<li data-i18n="hf">Hugging Face: modelos, datasets, Spaces e Kernels com Discussions fechadas. Exclui pull requests e autores-bot; preserva comentários de bots. Buckets não têm Discussions; Spaces gated são excluídos.</li>
<li data-i18n="licenses">Em ambas as plataformas, o repositório precisa ser público e usar licença SPDX aprovada pela lista OSI local. Não há limiar de popularidade.</li>
<li data-i18n="concepts">A configuração preserva 20 conceitos e a taxonomia de 24 categorias; palavras-chave não atribuem categorias automaticamente.</li>
</ul>

## Amostra {#dados}

<p data-i18n="sampling">Unidades com evidência legal, estratificadas por plataforma, tipo de repositório e lei. Cochran com correção para população finita: 99% de confiança, margem de 5% e proporção de 50%; sorteio sem reposição.</p>

<p data-i18n="exports">Arquivos de população, amostra, estratos e codificação são exportados em inputs/final/collection. Dados brutos e tokens não são copiados para o site.</p>

## Execução local {#reproducao}

```bash
Rscript main.R --help
Rscript main.R --pilot
Rscript main.R --run
quarto preview
```

<p data-i18n="full">--run coleta as duas plataformas e gera o site após a análise. A geração valida a cobertura e a integridade das respostas.</p>

<p data-i18n="publication">Os testes rodam em cada push para main. Com os testes aprovados, o workflow separado publica o site no GitHub Pages.</p>

## Limites {#limites}

<ul>
<li data-i18n="limits">Menções textuais não determinam conformidade legal. Os totais GitHub vêm de buscas por leis; a descoberta HF depende da indexação de licenças. O piloto é limitado.</li>
<li data-i18n="kernel_limit">A rota de listagem de Kernels ainda requer validação ao vivo de paginação e cobertura.</li>
</ul>

## Referências {#referencias-metodologicas}

{{REFERENCES}}
