Kapitsaki, G. M.; Papoutsoglou, M.; Treude, C.; Theophilou, I. (2026).
*Analyzing developer discussions on EU and US privacy legislation compliance in GitHub repositories*.
Information and Software Technology. [DOI: 10.1016/j.infsof.2026.108252](https://doi.org/10.1016/j.infsof.2026.108252).
[Preprint](https://arxiv.org/abs/2512.10618).
Fonte do procedimento de mineração de discussões, vocabulários e taxonomia.
O [pacote de replicação](https://github.com/gkapi/github-privacy-law-issues-analysis) foi preservado
em `inputs/reference/replication/`, no commit `eeccde00898a56d603748590fd5ce06fc05cba45`.
As palavras-chave revisadas pelo GPT pertencem ao pacote e têm origem distinguida das originais.
Os 20 conceitos têm listas originais; apenas 14 têm uma lista revisada no snapshot consultado.
As 24 categorias seguem o codebook HTML. O CSV de categorias também foi preservado e contém
rótulos de versões anteriores; ele não altera silenciosamente o codebook.

Gonzalez, D.; Zimmermann, T.; Nagappan, N. (2020).
*The State of the ML-universe: 10 Years of Artificial Intelligence & Machine Learning Software Development on GitHub*.
MSR. [DOI: 10.1145/3379597.3387473](https://doi.org/10.1145/3379597.3387473).
Antecedente de descoberta de projetos de IA/ML por tópicos.

Openja, M. et al. (2024). *An Empirical Study of Testing Machine Learning in the Wild*.
TOSEM. [DOI: 10.1145/3680463](https://doi.org/10.1145/3680463).
Origem bibliográfica dos primeiros 12 tópicos informados pelo usuário.
Os 24 tópicos deste projeto foram fornecidos diretamente pelo usuário; nenhum artigo
é apresentado como autor de toda a lista ou dos filtros deste protocolo.

Cohen, J. (1960). *A Coefficient of Agreement for Nominal Scales*.
Educational and Psychological Measurement. [DOI: 10.1177/001316446002000104](https://doi.org/10.1177/001316446002000104).
Referência de concordância para duas codificações independentes.

Cochran, W. G. (1977). *Sampling Techniques*, 3rd edition. Wiley.
Referência da fórmula de tamanho amostral, com correção para população finita.
Os parâmetros de 99%, 5% e 50% são decisões do protocolo informado pelo usuário.

### Extensão desta pesquisa: RQ3

Amershi, S.; Begel, A.; Bird, C.; DeLine, R.; Gall, H.; Kamar, E.;
Nagappan, N.; Nushi, B.; Zimmermann, T. (2019).
*Software Engineering for Machine Learning: A Case Study*.
ICSE-SEIP, pp. 291–300.
[DOI: 10.1109/ICSE-SEIP.2019.00042](https://doi.org/10.1109/ICSE-SEIP.2019.00042).
[Fonte primária](https://www.microsoft.com/en-us/research/publication/software-engineering-for-machine-learning-a-case-study/).
A seção II.B e a Figura 1 informam as nove etapas, com ciclos de retorno.
Os IDs, definições operacionais de preocupações regulatórias, regras de
evidência e adaptações para LLM em `ml-stages-1.0.0` são nossos.
Esse instrumento não substitui as 24 categorias de Kapitsaki et al.
O codebook e as instruções estão em `inputs/reference/rq3-codebook.md`.

### Literatura externa para interpretação

Conforme o pré-projeto atualizado, estes trabalhos contextualizam os
resultados; não fornecem as 24 categorias nem validam automaticamente a RQ3:

- Herwanto et al. (2024), *Toward a Holistic Privacy Requirements Engineering
  Process: Insights From a Systematic Literature Review*.
  [DOI: 10.1109/ACCESS.2024.3380888](https://doi.org/10.1109/ACCESS.2024.3380888).
- Kosenkov et al. (2026), *Privacy by design: Aligning GDPR and software
  engineering specifications with a requirements engineering approach*.
  [DOI: 10.1016/j.infsof.2025.107946](https://doi.org/10.1016/j.infsof.2025.107946).
- Sangaroonsilp et al. (2023), *A taxonomy for mining and classifying privacy
  requirements in issue reports*.
  [DOI: 10.1016/j.infsof.2023.107162](https://doi.org/10.1016/j.infsof.2023.107162).
- Mitchell et al. (2019), *Model Cards for Model Reporting*.
  [DOI: 10.1145/3287560.3287596](https://doi.org/10.1145/3287560.3287596).
- Gebru et al. (2021), *Datasheets for Datasets*.
  [DOI: 10.1145/3458723](https://doi.org/10.1145/3458723).
- Kapitsaki (2026), *Regulatory compliance-readiness in the AI Supply Chain:
  examining datasets in Hugging Face*.
  [Preprint arXiv:2607.03310](https://arxiv.org/abs/2607.03310).
  Seu objeto são cards de datasets; não equivale às Discussions nem aos
  critérios comuns de licenciamento desta pesquisa.

Documentação técnica: [GitHub Search](https://docs.github.com/en/rest/search/search),
[Hugging Face Hub API](https://huggingface.co/docs/hub/en/api),
[limites de comunicação do Hub](https://huggingface.co/docs/hub/en/rate-limits),
[lista SPDX](https://github.com/spdx/license-list-data) e
[Quarto no GitHub Pages](https://quarto.org/docs/publishing/github-pages.html).
