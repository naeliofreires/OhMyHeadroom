# Police Scan (limpar-mac)

Police Scan encontra arquivos que o Mac pode recriar sozinho (caches, pacotes baixados,
imagens do Docker, `node_modules` e builds de projetos e worktrees), mostra quanto
espaço cada categoria liberaria e apaga **somente o que você escolher**.

Ele tem duas formas de uso, que compartilham o mesmo motor:

- **Police Scan.app**: app de barra de menu (SwiftUI), com painel, confirmação e animação durante a medição.
- **`limpar-mac`**: comando de terminal com os mesmos números.

## Como funciona

```
 Police Scan.app (SwiftUI, barra de menu)        limpar-mac (terminal)
        │                                              │
        │ python3 limpar.py scan --json --progress     │ limpar.py scan | limpar
        │   ← relatório JSON (stdout)                  │
        │   ← passos "step" (stderr, para a animação)  │
        │ python3 limpar.py apagar --lang pt|en        │
        │   → plano JSON (stdin) com as categorias     │
        ▼                                              ▼
 ┌───────────────────────── limpar.py ──────────────────────────┐
 │  scan.py      mede (du, docker system df, varredura)         │
 │  progress.py  avisa qual pasta está sendo medida (stderr)    │
 │  plan.py      lê o JSON de entrada e valida cada campo        │
 │  i18n.py      textos em português e inglês                    │
 │  targets.py   as regras: o que olhar e o que só é revisão     │
 └──────────────────────────────────────────────────────────────┘
```

Toda a escrita em disco passa pelo motor. O app só lê o relatório e envia o plano
escolhido pelo usuário.

## Estrutura

```
~/.local/share/limpar-mac/
  limpar.py        comandos: scan, scan --json, limpar, limpar --yes, apagar
  scan.py          medição paralela e montagem do relatório (não apaga nada)
  targets.py       catálogo de regras: categorias seguras e pastas de revisão
  plan.py          fronteira JSON: valida o plano antes de qualquer remoção
  progress.py      eventos de progresso para a animação do app
  i18n.py          textos em pt e en, e escolha do idioma
  README.md        este arquivo
  menubar/         o app SwiftUI (Package.swift, Sources/PoliceScan, Localization)
    build-app.sh   compila e instala em ~/Applications/Police Scan.app
    Info.plist     nome, identificador do bundle e idiomas suportados
    Tools/make-icon.swift  gera o ícone (AppIcon.icns) em todos os tamanhos
    Resources/AppIcon.icns  ícone atual (lupa dourada sobre fundo preto)
    Localization/  Localizable.strings em en.lproj e pt-BR.lproj
~/.local/bin/limpar-mac   atalho de terminal para limpar.py
```

## Categorias

**Seguras** (o app ou a ferramenta recria; marcadas por padrão, exceto dependências):

| Categoria | O que é |
|---|---|
| Caches de apps e navegadores | conteúdo de `~/Library/Caches` |
| Pacotes baixados | `~/.npm`, store do pnpm, cache do yarn |
| Cache do Cursor e do Claude | só cache de extensões e interface |
| Logs antigos | `~/Library/Logs` |
| Docker: imagens e build cache sem uso | `docker image prune -a` e `docker builder prune` (volumes não são tocados) |
| Dependências em worktrees | `node_modules`, `.venv`, `.next`, `.turbo`, `__pycache__` em worktrees de agentes e do Herdr (desmarcada) |
| Dependências em projetos | as mesmas pastas em projetos principais (desmarcada) |

**Revisão** (medidas e listadas, nunca apagadas): imagem de VM do Claude, disco virtual do
Docker, volumes Docker sem uso, histórico do Codex, `~/.local/share`, estado do Cursor,
worktrees do Herdr, dados do MeetingMind e do WhatsApp, Downloads, Movies e Lixeira.

## Requisitos

- macOS 26 ou superior (o app usa o estilo Liquid Glass).
- Python 3.10 ou superior, em `/opt/homebrew/bin/python3` ou `/usr/local/bin/python3`.
  Testado com Python 3.14.
- Toolchain Swift para compilar o app. As Command Line Tools bastam, sem Xcode completo.
- Docker é opcional: sem ele, as linhas do Docker simplesmente não aparecem.

## Uso

Terminal:

```sh
limpar-mac                 # mede e mostra o relatório; não apaga nada
limpar-mac limpar          # pergunta s/N (ou y/N) para cada categoria segura
limpar-mac limpar --yes    # apaga todas as categorias seguras sem perguntar
```

Idioma: `--lang pt` ou `--lang en`. Sem a flag, vale a localidade do shell (`LANG`).

Comandos de integração, usados pelo app:

```sh
python3 limpar.py scan --json             # relatório JSON no stdout
python3 limpar.py scan --json --progress  # o mesmo, mais passos no stderr
python3 limpar.py apagar --lang pt        # lê o plano JSON no stdin e apaga
```

App: depois de `menubar/build-app.sh`, abra **Police Scan** em `~/Applications`. O ícone aparece na barra
de menu com o espaço livre. Clique em **Medir**, marque as categorias e use **Apagar selecionados…**.
O app segue o idioma do sistema.

## Compilar e instalar o app

```sh
cd ~/.local/share/limpar-mac/menubar
./build-app.sh             # swift build -c release, monta o bundle e assina
```

Para regenerar o ícone (só se quiser mudar o desenho):

```sh
mkdir -p Resources && swiftc Tools/make-icon.swift -o /tmp/make-icon && /tmp/make-icon Resources
```

## Segurança

- Só o conteúdo de pastas listadas é removido. A pasta em si fica.
- Caminhos fora da pasta do usuário são recusados.
- Caminhos relativos e planos com formato errado são recusados antes de qualquer remoção.
- Pastas de revisão nunca são apagadas pelo script.
- Sem resposta (stdin vazio) significa não. Por isso nada é apagado por engano.

## Permissões do macOS

Downloads e Lixeira são protegidos pelo macOS. Dê **Acesso Total ao Disco** ao "Police Scan"
em Ajustes > Privacidade e Segurança e meça de novo. Se o terminal for usado no lugar do app,
a permissão precisa ser dada ao terminal.

Limitação atual: a assinatura do app é ad-hoc, e ela muda a cada compilação. Por isso o
macOS pode pedir a permissão de novo depois de recompilar. A solução planejada é um
certificado local estável.

## Limitações conhecidas

- **Sem limite de tempo no `du`.** Uma pasta travada (já aconteceu com as pastas do
  MeetingMind e do WhatsApp) trava a medição inteira.
- **`apagar` aceita comandos vindos do plano.** A validação atual confere o formato,
  mas não restringe quais comandos rodam. A correção planejada é uma lista fixa de comandos
  definida pelo próprio motor.
- **Sem suíte de testes automatizados.** Os testes feitos até agora foram scripts pontuais.
- **Temporários não são medidos.** `/tmp` e a pasta temporária do usuário ficam de fora.
- **Dois arquivos grandes:** `scan.py` tem cerca de 400 linhas, acima do ideal de 300 do
  `CODE_STYLE`. Dividir por responsabilidade (Docker, dependências e medição) é o próximo passo.
- **Caminho fixo:** o app procura `~/.local/share/limpar-mac/limpar.py`. Mover a pasta
  exige ajustar `LimparEngine.locate()`.

## Desenvolvimento

- Textos novos de categoria ou de revisão entram em `targets.py` ou `scan.py`, sempre com
  versão em português e inglês (`Localized(pt=..., en=...)`).
- Textos da interface entram em `menubar/Localization/*.lproj/Localizable.strings`. A chave é o
  texto em inglês, e a tradução vai no `pt-BR`.
- Nomes de identificadores ficam em inglês. A interface e as mensagens ao usuário ficam
  em português e inglês.
