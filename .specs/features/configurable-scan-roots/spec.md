# Configurable Scan Roots Specification

**Approved**: 2026-11-26 - user: "Aprovo a especificação. Pode seguir com o plano."

## Problem Statement

O motor procura dependências de projetos apenas em `~/Developer`, `~/.herdr`, `~/.t3` e `~/.synara`. Quem usa pastas como `~/Projects`, `~/Code` ou `~/workspace` precisa mudar o código para que seus projetos apareçam na varredura.

## Goals

- Permitir adicionar e remover pastas de busca nas opções do app e usar a seleção em futuras varreduras.
- Permitir escolher as pastas de busca para uma varredura da CLI.

## Out of Scope

| Item | Motivo |
| --- | --- |
| Pastas de cache, logs, Docker e revisão manual | A lista governa a descoberta de dependências de projetos e worktrees. |
| Edição persistente pela CLI | A flag configura uma única execução. |
| Alterar os comandos `clean` e `apply` | O pedido da CLI cobre a varredura `scan`. |
| Exclusão de pastas pelo editor de raízes | Remover uma entrada altera a configuração de busca. |

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Lista inicial e vazia | Começar com as quatro pastas atuais. Permitir remover todas. | Resposta `editable` em `context.md`. | y |
| Duração e precedência da flag | `--scan-root PASTA` substitui a lista padrão para a execução. | Resposta `replace` em `context.md`. | y |
| Relatório aberto | Uma edição efetiva volta ao estado inicial e requer outro Scan. | Resposta `reset` em `context.md`. | y |
| Pasta indisponível | Recusar caminho inválido explícito na CLI. Preservar entradas salvas e pular pastas indisponíveis no app. | Resposta `skip_saved` em `context.md`. | y |
| Superfície de opções e idioma | Usar o menu existente, os idiomas inglês e português brasileiro e as dimensões do painel atual. | O app já oferece preferências locais em um painel de 500 × 580. | n |
| Forma de selecionar pastas e salvar | Usar o seletor nativo do macOS. Cada edição efetiva é salva localmente. | O app aplica cada alteração de preferência quando o usuário a faz. | n |
| Estados ocupados | Disponibilizar a edição entre operações. | `CleanupModel.isBusy` já bloqueia ações que alteram o estado durante varredura ou limpeza. | n |
| Duplicatas | Uma pasta descoberta por várias raízes aparece uma vez no relatório. | As categorias de dependências medem e somam pastas individuais. | n |

**Open questions:** none.

## User Stories

### P1: Gerenciar pastas de busca no app

**User Story**: Como desenvolvedor, quero escolher onde o app procura dependências para encontrar projetos fora das pastas padrão.

**Acceptance Criteria**:

1. WHEN o usuário abre a configuração de pastas pelas opções do app pela primeira vez THEN o app SHALL listar `~/Developer`, `~/.herdr`, `~/.t3` e `~/.synara`, mesmo quando alguma delas ainda não existe. [ROOT-01]
2. WHEN o usuário confirma uma nova pasta no seletor nativo THEN o app SHALL acrescentá-la à lista visível. [ROOT-02]
3. WHEN o usuário aciona a remoção de uma entrada THEN o app SHALL retirar a entrada da lista e preservar a pasta e seu conteúdo no disco. [ROOT-03]
4. WHEN o usuário reabre o app depois de editar a lista THEN o app SHALL recuperar a lista salva, inclusive se ela estiver vazia. [ROOT-04]
5. WHEN o usuário inicia um Scan com uma lista salva THEN o app SHALL buscar dependências nas pastas dessa lista, inclusive em uma pasta nova fora das quatro padrão, e excluir da descoberta pastas padrão removidas que estejam fora das raízes ativas. [ROOT-05]
6. WHEN o usuário inicia um Scan com a lista vazia THEN o app SHALL concluir a varredura sem buscar dependências e continuar a medir as demais categorias. [ROOT-06]
7. WHEN o usuário altera efetivamente a lista com um relatório aberto THEN o app SHALL descartar o relatório e a seleção de limpeza e voltar à tela inicial com a ação Scan disponível. [ROOT-07]
8. IF uma raiz salva estiver indisponível durante o Scan THEN o app SHALL continuar a busca nas outras raízes e manter a entrada na lista quando o usuário voltar à configuração. [ROOT-08]
9. WHILE o app está medindo o disco ou limpando uma seleção o app SHALL bloquear ações que alterem a lista de raízes. [ROOT-09]
10. WHEN o usuário cancela o seletor ou escolhe uma pasta que já consta na lista THEN o app SHALL preservar a lista e o relatório atuais. [ROOT-10]

**Independent Test**: Adicionar uma pasta temporária que contém um projeto, fazer Scan, conferir suas dependências e remover a raiz. Conferir que o relatório foi fechado, que a próxima varredura deixa de mostrar a pasta e que a edição persiste ao reabrir o app.

### P1: Escolher pastas em uma execução da CLI

**User Story**: Como usuário da CLI, quero indicar onde procurar dependências sem alterar as preferências do app.

**Acceptance Criteria**:

1. WHEN o usuário executa `scan` explícito ou implícito com uma ou mais ocorrências de `--scan-root PASTA` THEN a CLI SHALL usar como raízes apenas as pastas informadas, tanto na saída de texto quanto na saída JSON. [ROOT-11]
2. WHEN o usuário executa `scan` sem `--scan-root` THEN a CLI SHALL usar as quatro pastas padrão, independentemente das preferências do app. [ROOT-12]
3. IF uma ocorrência de `--scan-root` não tiver valor ou indicar uma pasta inexistente ou inacessível ou um arquivo THEN a CLI SHALL indicar o erro em `stderr` e encerrar com status 2 antes de emitir um relatório. [ROOT-13]
4. WHEN o usuário consulta `--help` THEN a CLI SHALL documentar `--scan-root PASTA` como uma opção repetível de `scan` que substitui a lista padrão para aquela execução. [ROOT-14]

**Independent Test**: Executar `scan --json` com duas raízes temporárias e conferir que ambas aparecem no relatório e que as raízes padrão foram excluídas. Em outra execução sem flags, conferir o uso dos padrões. Passar um arquivo e conferir o erro e o status.

## Edge Cases

- WHEN a mesma pasta de dependências é alcançada por raízes repetidas ou sobrepostas THEN o relatório SHALL incluir essa pasta e seu tamanho uma única vez. [ROOT-15]

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| ROOT-01 | App | Specify | Pending |
| ROOT-02 | App | Specify | Pending |
| ROOT-03 | App | Specify | Pending |
| ROOT-04 | App | Specify | Pending |
| ROOT-05 | App | Execute | Implementing |
| ROOT-06 | App | Execute | Implementing |
| ROOT-07 | App | Specify | Pending |
| ROOT-08 | App | Execute | Implementing |
| ROOT-09 | App | Specify | Pending |
| ROOT-10 | App | Specify | Pending |
| ROOT-11 | CLI | Execute | Verified |
| ROOT-12 | CLI | Execute | Verified |
| ROOT-13 | CLI | Execute | Verified |
| ROOT-14 | CLI | Execute | Verified |
| ROOT-15 | App e CLI | Execute | Verified |

## Sources

- Pedido do usuário para configurar pastas de projetos nas opções do app e por flag da CLI.
- `context.md` registra as quatro decisões de comportamento do usuário.
- `ohmyheadroom_engine/features/cleanup/catalog.py` define as quatro raízes atuais.
- `Sources/OhMyHeadroom/Features/Cleanup/Views/PanelHeaderView.swift` contém o menu de opções.

## Success Criteria

- [ ] Um desenvolvedor consegue descobrir pelo app as dependências de um projeto fora das raízes padrão e retirar essa pasta de futuras varreduras.
- [ ] Uma execução da CLI consegue buscar somente nas pastas escolhidas para aquele comando.
