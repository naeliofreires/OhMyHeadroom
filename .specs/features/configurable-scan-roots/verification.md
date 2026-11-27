# Configurable Scan Roots verification

**Verdict**: FAIL
**Proofs**: `proofs.md` at `0ba17c4e47`
**Corrections**: `683480ea4e`
**Verifier**: independent sub-agent (author != verifier)

## Checks

| Check | Test | Holds |
| --- | --- | --- |
| C01 | `Tests/OhMyHeadroomTests/ScanRootChecks.swift:26` `checkDefaultScanRoots` | yes — compara exatamente as quatro raízes iniciais; `CleanupModel.init` não filtra pela existência no disco. A prova é do modelo, não da apresentação do menu/editor. |
| C02 | `checkAddScanRoot` e visita ao seletor nativo | yes — o usuário confirmou que a pasta apareceu no editor após `Add folder`. A preferência do bundle de teste também continha a nova pasta. |
| C03 | `Tests/OhMyHeadroomTests/ScanRootChecks.swift:41` `checkRemoveScanRoot` | yes — verifica a lista resultante e lê novamente os bytes de um arquivo real dentro da dependência da raiz removida. |
| C04 | `Tests/OhMyHeadroomTests/ScanRootChecks.swift:66` `checkPersistedScanRoots` | yes — reabre com a mesma suite isolada, compara a lista exata após remoção/adição e verifica a persistência da lista vazia. |
| C05 | `Tests/Python/test_scan_roots_cli.py:130` `test_app_scan_uses_saved_roots` | yes — exercita o despacho e o relatório reais com o transporte stdin do app; compara todas as dependências da raiz nova e da raiz padrão mantida, excluindo as demais. O teste Swift adicional `checkAppScanSendsSavedRoots` cobre o transporte modelo/gateway. |
| C06 | `test_app_scan_with_empty_roots_keeps_other_categories` | yes — a prova corrigida em `683480ea4e` exige os valores de cache, Docker e revisão, com ausência de dependências. |
| C07 | `checkScanRootChangeClearsReport` | yes — a prova corrigida em `683480ea4e` abre um relatório com uma dependência selecionada antes de cada tipo de edição e exige estado inicial, relatório e seleção vazios após adicionar ou remover. |
| C08 | `tasks.md:152-153` walk: salvar duas raízes, mover uma, fazer Scan e reabrir a configuração | yes — o roteiro verifica descoberta na raiz disponível e conservação da entrada indisponível; `proofs.md:17` registra a visita como realizada. Não foi repetida nesta verificação. O exemplo próprio abaixo confirmou a parte de descoberta. |
| C09 | `Tests/OhMyHeadroomTests/ScanRootChecks.swift:95` `checkBusyScanRootEdits` | yes — bloqueia o gateway nas duas fases, tenta adicionar/remover, compara fase e raízes e verifica que as edições não alcançaram as preferências. |
| C10 | `checkIgnoredScanRootEdits` e visita ao seletor nativo | no — o modelo preserva a lista e o relatório com cancelamento e duplicata. O serviço do seletor macOS não aceitou os eventos automatizados para verificar esses dois retornos na janela final, e o usuário informou que não tinha acesso à janela na segunda solicitação. |
| C11 | `Tests/Python/test_scan_roots_cli.py:78` `test_scan_root_flags_replace_defaults_in_text_and_json` | yes — cobre comando explícito/implícito e texto/JSON com duas flags, exige ambas as raízes escolhidas e exclui as padrão. |
| C12 | `test_scan_without_flag_uses_four_default_roots` | yes — a prova corrigida em `683480ea4e` chama a CLI real com um home temporário e uma preferência do app escrita no local correspondente, primeiro com uma raiz personalizada e depois com lista vazia. Em ambos os casos, encontra os projetos das quatro raízes padrão. |
| C13 | `Tests/Python/test_scan_roots_cli.py:98` `test_invalid_scan_root_exits_before_reporting` | yes — cobre os quatro casos nomeados, inclusive acesso negado controlado; exige status 2, stdout vazio, diagnóstico e nenhuma medição pelo runner. |
| C14 | `Tests/Python/test_scan_roots_cli.py:119` `test_help_describes_repeating_scan_roots` | yes — exige a sintaxe de scan e a frase de repetição/substituição em ambos os idiomas, sem erro. |
| C15 | `test_overlapping_roots_count_each_dependency_once` | yes — a prova corrigida em `683480ea4e` inclui uma raiz equivalente e uma raiz sobreposta por link simbólico. Exige um caminho, uma contribuição de tamanho e uma medição. |

## Findings

| Finding | Evidence | Fix | Closed |
| --- | --- | --- | --- |
| F1 — Contagem duplicada com aliases de raiz. | Exemplo próprio 1 e C15. | Deduplicar a raiz resolvida e a identidade do caminho antes de medir. | `683480ea4e` (C15) |
| F2 — Cobertura do retorno do seletor nativo. | C02/C10 e visita registrada em `tasks.md`. | A visita confirmou a adição com o usuário. Cancelamento e confirmação de duplicata seguem pendentes na janela real e passam no modelo. | |
| F3 — Cobertura parcial de outras categorias com lista vazia. | C06. | Verificar valores de cache, Docker e revisão. | `683480ea4e` (C06) |
| F4 — Cobertura da invalidação por adição. | C07. | Verificar descarte de relatório e seleção em adição e remoção. | `683480ea4e` (C07) |
| F5 — Independência das preferências do app. | C12. | Exercitar a CLI com preferências de lista personalizada e lista vazia em um home isolado. | `683480ea4e` (C12) |

## Own examples

Executados em HEAD com diretórios temporários reais e o despacho `commands.main(["scan", "--json", "--scan-roots-stdin"], "en")`. A composição do relatório foi limitada ao filesystem temporário, sem regras de cache/revisão; Docker foi isolado e o runner permitiu somente `du -sk --` sobre caminhos da fixture. Nenhuma varredura do home, operação de limpeza, suíte normal, build ou `check_proofs` foi executada.

Fixture preservada: `/private/var/folders/wh/_ggpx1y555n0bjcqh27z0dfm0000gn/T/headroom-independent-verifier-tgvarqt8`.

1. **ROOT-15 — duas raízes equivalentes por link simbólico:** `actual` e `linked -> actual`, com uma única dependência `actual/project/node_modules` e payload de 16.384 bytes. **FAIL:** duas entradas, ambas resolvendo para a mesma pasta; cada entrada tinha 16.384 bytes e o total foi 32.768 (F1).
2. **ROOT-08 — raízes indisponíveis antes e depois da disponível:** lista `[disconnected, actual, also-unavailable]`, com duas pastas inexistentes. **PASS:** status 0, stderr vazio e apenas `actual/project/node_modules`, com total de 16.384 bytes. Este exemplo verifica a descoberta; a conservação da configuração no editor continua sustentada pelo walk de C08 e pela cobertura de persistência, não por esta chamada Python.
