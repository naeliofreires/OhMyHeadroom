# Configurable Scan Roots Tasks

## Execution Protocol

Executar as tarefas com a skill `tlc-spec-driven`. Registrar o resultado do gate e marcar cada tarefa antes do seu commit local. Ao final, registrar a visita ao app e à CLI, executar os checks de `HEAD` e solicitar a avaliação independente prevista na skill.

**Spec**: `.specs/features/configurable-scan-roots/spec.md`
**Status**: In Progress
**Approved**: 2026-11-26 - user: "Aprovo o plano. Pode implementar na branch atual."
**Build**: `make build-swift`
**Run discovery**: `python3 -m unittest discover -s Tests/Python -p test_scanning_adapters.py -v`
**Run cli**: `python3 -m unittest discover -s Tests/Python -k ConfigurableScanRootsCliTests -k CommandTests -k TrashCliTests -v`
**Run app**: `make test-swift`

## Design

A CLI resolve as raízes para a varredura e passa a lista ao `ScanRuntime` já aceito por `build_report`. A opção pública `--scan-root PASTA` exige diretórios acessíveis e vale para `scan` explícito ou implícito. O app usa o mesmo comando em modo JSON com `--scan-roots-stdin` e envia a lista por stdin, seguindo o transporte já usado por `apply`. A entrada do app aceita `[]` e preserva caminhos salvos que venham a ficar indisponíveis. O caminho padrão da CLI continua vindo do catálogo Python. A descoberta elimina caminhos repetidos antes de medir.

No Swift, `CleanupModel` carrega as raízes de `UserDefaults`, distingue a ausência da preferência de uma lista salva vazia, protege a edição com `isBusy` e reutiliza `reset()` após alterações efetivas. `CleanupGateway` leva uma cópia da lista para cada varredura. O catálogo Python e a lista inicial do app declaram os quatro caminhos compatíveis com o comportamento atual. O menu abre uma janela de preferências com lista rolável, estado vazio, seletor nativo de diretórios e remoção por linha. O teste do popover encontrou um problema de foco ao usar o seletor como folha. A janela de preferências permite abrir o seletor sem fechar o editor. As regras de edição e as transições ficam no modelo. As strings seguem os recursos localizados do app.

O processo do app e a CLI precisam de comportamentos diferentes para volumes removidos ou entradas ausentes. O teste da interface entre os processos cobre esse contraste, além do caso de `[]` e de caminhos com espaços. A visita usa um bundle e uma preferência isolados, com projetos temporários e sem executar limpeza. Ela cobre a interação com o seletor, que o runner Swift não abre.

## Test Coverage Matrix

> Generated from codebase, project guidelines, and spec - confirm before Execute. Guidelines found: `README.md` (Verification, Development), `Makefile`, `Tools/check-swift.sh`.

| Code Layer | Required Test Type | Coverage Expectation | Location Pattern | Run Command |
| --- | --- | --- | --- | --- |
| Descoberta Python | unit | Caminhos iguais encontrados por raízes repetidas e sobrepostas aparecem uma vez e contribuem uma vez para o total. Os testes de classificação e ordenação continuam passando. | `Tests/Python/test_scanning_adapters.py` | `Run discovery` |
| CLI Python e entrada do app | integration | Despacho real e relatório de fixtures para raízes explícitas, omitidas, vazias e indisponíveis, além de erros de entrada e ajuda localizada. Adaptadores isolam medições externas nas fixtures. | `Tests/Python/test_scan_roots_cli.py`, `Tests/Python/test_cleanup_engine.py`, `Tests/Python/test_trash_cli.py` | `Run cli` |
| Preferências, modelo e gateway Swift | unit / integration | Suite de `UserDefaults` isolada, transições observáveis e transporte com array JSON, incluindo uma lista vazia. | `Tests/OhMyHeadroomTests/*Checks.swift` | `Run app` |
| Editor macOS | e2e | Abrir pelo menu, adicionar, cancelar, remover, verificar estado vazio e verificar o relatório após nova varredura e reabertura. | Visita registrada em `## Handoff` | App macOS em bundle de teste |

## Gate Check Commands

> Generated from codebase - confirm before Execute.

| Gate Level | When to Use | Command |
| --- | --- | --- |
| Quick | Descoberta Python | `python3 -m unittest discover -s Tests/Python -p test_scanning_adapters.py -v` |
| CLI | Comando `scan` e regressões dos outros comandos | `python3 -m unittest discover -s Tests/Python -k ConfigurableScanRootsCliTests -k CommandTests -k TrashCliTests -v` |
| App | Modelo Swift e contrato com o motor | `make test-swift` |
| Build | Baseline, interface SwiftUI e revisão final | `make build-swift` |
| Walk | Controles nativos e varredura em um app empacotado | Abrir o bundle de teste com `open -n` e usar o menu do app e pastas temporárias. |

## Execution Plan

### Phase 1: Scan roots

```text
T1 → T2 → T3 → T4
```

## Task Breakdown

### T1: Contar uma vez cada pasta descoberta

**What**: Consolidar caminhos descobertos em raízes repetidas ou sobrepostas antes de medir as dependências.
**Where**: `ohmyheadroom_engine/features/cleanup/scanning/dependencies.py`
**Depends on**: None
**Reuses**: `collect_dependency_dirs`, `sized_paths` e `FakeScanFileSystem`.
**Requirement**: ROOT-15

**Done when**:

- [x] Uma pasta encontrada por três entradas, com repetição e sobreposição, aparece uma vez no relatório e seu tamanho entra uma vez no total, ao lado de um segundo projeto distinto.
- [x] `Run discovery` passou com 6 testes.

**Tests**: unit, `test_overlapping_roots_count_each_dependency_once` no arquivo de testes de varredura existente.
**Gate**: Quick.
**Commit**: `fix(scan): count overlapping dependency paths once`

### T2: Receber raízes no comando scan

**What**: Fazer `scan` receber raízes pela opção pública repetível ou pela entrada JSON usada pelo app. Reusar os quatro padrões quando nenhuma lista for enviada e documentar a opção pública na ajuda e no README.
**Where**: `ohmyheadroom_engine/cli/commands.py`
**Depends on**: T1
**Reuses**: `ScanRuntime.dependency_roots`, `build_report`, a ajuda localizada em `cli/presentation.py` e o contrato de stdin usado por `apply`.
**Requirement**: ROOT-05, ROOT-06, ROOT-08, ROOT-11, ROOT-12, ROOT-13, ROOT-14

**Done when**:

- [x] A saída humana e JSON usa apenas os caminhos pedidos com `--scan-root`. Sem a opção, usa os quatro padrões. Entradas inválidas falham com status 2 e diagnóstico em stderr antes de emitir o relatório.
- [x] O comando usado pelo app aceita uma lista de caminhos com espaços, uma lista vazia e uma raiz salva indisponível ao lado de outra válida. O relatório continua medindo categorias comuns.
- [x] A ajuda em português e inglês explica que a opção é repetível e substitui as raízes padrão para `scan`.
- [x] `Run cli` passou com 22 testes.

**Tests**: integration, sete casos novos em `Tests/Python/test_scan_roots_cli.py`. Exercitar o comando e o relatório enquanto as fixtures controlam a árvore de diretórios e as medições.
**Gate**: CLI.
**Commit**: `feat(cli): accept custom dependency scan roots`

### T3: Aplicar preferências de raízes nas varreduras do app

**What**: Gerenciar as raízes persistidas no modelo e entregar uma cópia da lista à varredura por meio do gateway e do transporte existentes.
**Where**: `Sources/OhMyHeadroom/Features/Cleanup/CleanupModel.swift`
**Depends on**: T2
**Reuses**: `UserDefaults`, `CleanupModel.reset`, `CleanupGateway`, `CleanupEngine`, `EngineJSON` e os fakes Swift registrados em `CheckCases.swift`.
**Requirement**: ROOT-01, ROOT-02, ROOT-03, ROOT-04, ROOT-05, ROOT-06, ROOT-07, ROOT-08, ROOT-09, ROOT-10

**Done when**:

- [x] O modelo expõe os quatro padrões na primeira leitura e salva adições e remoções. Outra instância recupera a configuração, incluindo uma lista vazia ou uma entrada temporariamente indisponível.
- [x] Uma alteração efetiva descarta o relatório pronto e a seleção. Duplicatas, cancelamento e tentativas durante scan ou limpeza preservam a lista e o estado da operação.
- [x] O gateway envia a lista exata no comando, incluindo caminhos com espaços e `[]`. O modelo preserva a entrada no caso indisponível coberto em T2.
- [x] `Run app` passou com 36 checks.

**Tests**: unit e integration, sete checks de preferência e modelo e um check do contrato de transporte em `Tests/OhMyHeadroomTests/ScanRootChecks.swift`.
**Gate**: App.
**Commit**: `feat(app): persist roots and use them for scans`

### T4: Gerenciar as raízes pelo menu de opções

**What**: Abrir a janela de pastas de projetos pelo menu do painel macOS, com seletor de diretórios, remoção de entradas, estado vazio e strings localizadas. Documentar como abrir o editor no README.
**Where**: `Sources/OhMyHeadroom/Features/Cleanup/Views/PanelHeaderView.swift`
**Depends on**: T3
**Reuses**: Menu e dimensões existentes, operações do modelo, `NSOpenPanel`, `PathDisplay` e `Localization/*.lproj/Localizable.strings`.
**Requirement**: ROOT-01, ROOT-02, ROOT-03, ROOT-04, ROOT-05, ROOT-06, ROOT-07, ROOT-08, ROOT-09, ROOT-10

**Done when**:

- [x] Pelo menu, o usuário abriu a lista inicial, confirmou a adição de uma pasta de teste, viu o projeto após Scan, removeu a raiz e voltou ao estado inicial.
- [ ] Cancelar a seleção e confirmar uma duplicata no seletor nativo com um relatório ativo preserva o relatório e a lista. Ambos os resultados passaram no teste de modelo.
- [x] A pasta permanece no disco. Uma nova varredura exclui seu conteúdo da descoberta e a edição persiste ao reabrir o app. A janela apresenta a lista vazia com a opção de adicionar disponível.
- [x] `make build-swift` terminou com status 0, e a visita foi feita no app empacotado em um bundle de teste.

**Tests**: e2e nativo, registrado no Handoff. As regras acionadas pelos controles têm checks de modelo e motor nas tarefas anteriores.
**Gate**: Build e Walk.
**Commit**: `feat(app): manage scan roots from the options menu`

## Checks

**C01** - A primeira configuração mostra `~/Developer`, `~/.herdr`, `~/.t3` e `~/.synara`, inclusive se ausentes no disco (ROOT-01, App AC 1).
Proof: run app | PASS scan roots start with four defaults

**C02** - Confirmar uma nova pasta acrescenta essa pasta à lista (ROOT-02, App AC 2).
Proof: run app | PASS adding a scan root appends the folder

**C03** - Remover uma raiz retira a entrada e preserva o diretório e seus arquivos (ROOT-03, App AC 3).
Proof: run app | PASS removing a scan root preserves its files

**C04** - O modelo reaberto recupera a lista salva, inclusive vazia (ROOT-04, App AC 4).
Proof: run app | PASS reopening restores the exact scan roots

**C05** - Um scan iniciado com a configuração do app encontra dependências na raiz nova e exclui as da raiz padrão removida (ROOT-05, App AC 5).
Proof: run cli | test_app_scan_uses_saved_roots (test_scan_roots_cli.ConfigurableScanRootsCliTests.test_app_scan_uses_saved_roots) ... ok

**C06** - Com raízes do app vazias, o relatório não contém pastas de dependências e mantém os resultados de cache, Docker e revisão da fixture (ROOT-06, App AC 6).
Proof: run cli | test_app_scan_with_empty_roots_keeps_other_categories (test_scan_roots_cli.ConfigurableScanRootsCliTests.test_app_scan_with_empty_roots_keeps_other_categories) ... ok

**C07** - Alterar a lista com um relatório pronto encerra a seleção, descarta o relatório e volta ao estado inicial de Scan (ROOT-07, App AC 7).
Proof: run app | PASS changing scan roots clears an open report

**C08** - Com uma pasta salva indisponível, o app descobre os projetos de outra raiz e conserva a entrada indisponível ao reabrir o editor (ROOT-08, App AC 8).
Proof: walk - Salvar duas pastas, mover uma delas no disco, executar Scan, conferir as dependências da outra e reabrir a lista para conferir a entrada original.

**C09** - Nenhuma edição se efetiva durante a medição ou a limpeza (ROOT-09, App AC 9).
Proof: run app | PASS scan roots cannot change during scan or cleanup

**C10** - Cancelar o seletor ou confirmar uma pasta duplicada preserva relatório e raízes (ROOT-10, App AC 10).
Proof: run app | PASS cancelling or repeating a scan root preserves the report

**C11** - `--scan-root` repetida escolhe apenas as raízes fornecidas, em texto e JSON, com comando `scan` explícito ou implícito (ROOT-11, CLI AC 1).
Proof: run cli | test_scan_root_flags_replace_defaults_in_text_and_json (test_scan_roots_cli.ConfigurableScanRootsCliTests.test_scan_root_flags_replace_defaults_in_text_and_json) ... ok

**C12** - A CLI sem `--scan-root` encontra os projetos de cada uma das quatro raízes padrão e exclui projetos fora delas (ROOT-12, CLI AC 2).
Proof: run cli | test_scan_without_flag_uses_four_default_roots (test_scan_roots_cli.ConfigurableScanRootsCliTests.test_scan_without_flag_uses_four_default_roots) ... ok

**C13** - Uma flag sem valor, uma pasta inexistente, uma pasta inacessível ou um arquivo gera diagnóstico em stderr e saída 2 sem relatório (ROOT-13, CLI AC 3).
Proof: run cli | test_invalid_scan_root_exits_before_reporting (test_scan_roots_cli.ConfigurableScanRootsCliTests.test_invalid_scan_root_exits_before_reporting) ... ok

**C14** - A ajuda nos dois idiomas documenta o uso repetível de `--scan-root PASTA` e a substituição dos padrões em `scan` (ROOT-14, CLI AC 4).
Proof: run cli | test_help_describes_repeating_scan_roots (test_scan_roots_cli.ConfigurableScanRootsCliTests.test_help_describes_repeating_scan_roots) ... ok

**C15** - Raízes repetidas ou sobrepostas produzem uma entrada e uma contribuição de tamanho por pasta de dependências (ROOT-15, Edge Cases 1).
Proof: run discovery | test_overlapping_roots_count_each_dependency_once (test_scanning_adapters.ScanningAdapterTests.test_overlapping_roots_count_each_dependency_once) ... ok

## Handoff

**Settled mid-build:** Confirmação do seletor nativo no bundle de teste, opção escolhida pelo usuário: "Sim, a pasta apareceu na lista". Para a visita de cancelamento: "Não consigo acessar a janela agora".
**Dispatched:** Verifier at `0ba17c4e47`, returned.
**Walked:** App empacotado no macOS com identificador e preferências de teste isolados. Pelo ícone da barra de menus, `More options → Project folders…` mostrou as quatro raízes iniciais. O usuário confirmou que `Add folder` adicionou `Active Project`, também presente na preferência salva. Para verificar a descoberta com uma raiz indisponível, duas raízes foram salvas no domínio de teste e uma foi movida. `Scan` encontrou `Alpha/node_modules` na raiz disponível e o editor conservou `Missing Project`. O botão de remoção retirou `Active Project`, preservou seu arquivo sentinela e o painel voltou a `Ready to scan`. O Scan seguinte deixou de listar `Alpha/node_modules`. Após remover a última entrada e reabrir o app, o editor mostrou `No project folders` com `Add folder…`. A automação abriu e observou o seletor sobre um relatório pronto, mas não conseguiu acionar o cancelamento ou a confirmação de uma duplicata pelo serviço do macOS. A CLI, em árvore temporária, listou apenas `Cli Default/node_modules` sem flags e listou `Alpha/node_modules` e `Beta/.venv` com duas flags. Uma raiz inexistente retornou status 2, diagnóstico em stderr e stdout vazio.
