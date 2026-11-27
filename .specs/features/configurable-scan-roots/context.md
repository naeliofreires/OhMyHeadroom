# Configurable Scan Roots Context

**Gathered:** 2026-11-26  
**Spec:** `.specs/features/configurable-scan-roots/spec.md`

## Feature Boundary

As opções do app gerenciam as pastas em que o OhMyHeadroom procura dependências de projetos. Uma flag da CLI permite escolher as pastas para uma execução da varredura.

## Implementation Decisions

- Lista inicial no app (`editable`): “Começar com as quatro pastas atuais e permitir remover qualquer uma. Uma lista vazia desativa a busca de dependências.”
- Escopo da flag da CLI (`replace`): “Usar --scan-root PASTA repetível para definir a lista inteira nessa execução. Sem a flag, a CLI usa as quatro pastas atuais.”
- Relatório após editar a lista (`reset`): “Voltar ao estado inicial e pedir uma nova busca, para que pastas removidas saiam da seleção de limpeza.”
- Pastas indisponíveis (`skip_saved`): “Recusar um caminho inválido informado à CLI. Se uma pasta já salva no app ficar indisponível, mantê-la na lista e continuar a busca nas outras.”
