# Dynamic Island — Conceitos Preservados (Kamalen Shell)

> Snapshot antes da reescrita do zero. Capturado em 2026-07-05.

## 1. Layout Adaptativo (DPI-aware)

```qml
readonly property real screenW: islandWindow.width > 0 ? islandWindow.width : 1920
readonly property real sf: Math.max(0.65, Math.min(2.0, screenW / 1920))
function dp(base) { return Math.round(base * sf) }
```

- `sf` normaliza à largura lógica de 1920px
- Scale 1.0 → sf=1.0 | Scale 1.25 → sf≈0.80 | Scale 1.5 → sf≈0.67
- Todas as dimensões usam `dp(base)` — nunca hardcodeadas

### Dimensões-base (em design pixels, antes de sf):

| Estado | Width | Height |
|--------|-------|--------|
| bump (idle) | 304 | 44 |
| strip (idle alt) | 98 | 4 |
| peek (hover/pin) | 442 | 172 |
| notify | 438 | 74 |
| media | 380 | 132 |
| launcher | 520 | 380 |

- `windowHeight = dp(136)` — altura total do PanelWindow
- `reservedZone = dp(24)` — exclusiveZone

## 2. Animações Goey

```qml
// Spring curve goey
NumberAnimation { duration: 330; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
```

- Usada em `width`, `height` dos anti-corners e shape transitions
- `[0.34, 1.22, 0.64, 1]` — bezier alternativo para smoother feel
- `Animations.medium` / `Animations.fast` para durações consistentes

## 3. Click-outside-to-close (Mask dinâmico)

```qml
mask: Region {
    item: (root.pinnedOpen || root.visualMode === "media" || root.visualMode === "launcher")
          ? windowContent    // full-window: captura cliques em toda tela
          : interactionMask  // apenas área da ilha: não rouba cliques do desktop
}
```

- `interactionMask` acompanha `island.x/y/width/height` com padding de 8px
- `clickCatcher` (MouseArea fullscreen) fica BEHIND da ilha (z:0 vs z:20)
- `islandHitbox` absorve cliques diretos na ilha

### Bug encontrado: `island.x` pode não estar disponível quando mask é avaliado

Solução atual: `id: windowContent` explícito + referência `windowContent` no Region.item.

## 4. Keyboard Navigation

```qml
Keys.onPressed: event => {
    if (event.key === Qt.Key_Escape) { ... close ... }
    else if (root.mode === "launcher") {
        if (event.key === Qt.Key_Return) { ... launch ... }
        else if (event.key === Qt.Key_Up) { ... moveSelection(-1) ... }
        else if (event.key === Qt.Key_Down) { ... moveSelection(1) ... }
    }
}
```

- Esc fecha qualquer surface
- Setas navegam no launcher
- Enter lança app selecionado

## 5. Shoulders Dinâmicos (Anti-corners)

```qml
readonly property real shoulderW: Math.max(8, Math.min(width * 0.06, 20))
readonly property real shoulderH: Math.max(6, Math.min(height * 0.4, 13))
```

- Ombreiras côncavas que fundem a ilha com a borda da tela
- Escalam com as dimensões da ilha (DPI-safe)
- Renderizadas com `Shape { ShapePath { PathCubic { ... } } }`
- `antiCornerRadius` controla visibilidade

## 6. States / Modes

```
mode → "idle" | "notify" | "media" | "launcher"
visualMode → mode real exibido (media quando hover+playing)
interactionOpen → idle mas com hover/pin (mostra peek)
```

Transições via `Behavior on width/height` com `Easing.OutBack`.

## 7. Sistema de Cores (Iris)

- `iris.py` extrai paleta do wallpaper via PIL+numpy
- Output JSON: `{bg, fg, accent, green, red, yellow, surface, dim, tone_l}`
- `Colors.qml` é singleton com `ColorAnimation` em todas as props (300ms OutCubic)
- Dark/light mode automático baseado em `tone_l` (luminância)
- `Colors.a(color, opacity)` helper para alpha
- `UIState.transparencyEnabled` controla vidro/blur

## 8. Estrutura Atual de Arquivos

```
DynamicIsland.qml  — PanelWindow, state machine, IPC, signal routing (~798 linhas)
IslandSurface.qml  — Renderização visual: shapes, shadows, glow, sheen (~400+ linhas)
IslandContent.qml  — Conteúdo interno: clock, tray, media, launcher, settings (~1943 linhas)
IslandWidget.qml   — Wrapper menor (legacy?)
IslandWallpaper.qml — Wallpaper blur/glass effect
IslandTray.qml     — Tray icons standalone
```

## 9. Problemas Conhecidos (a evitar na reescrita)

1. **Valores hardcoded em IslandContent.qml** — font.pixelSize 8-29, tray 29×22, settings height 42
   → SOLUÇÃO: tudo proporcional a `height` da ilha via `dp()` ou `height * ratio`
2. **TypeError tray linha 407** — `Cannot read property 'window' of undefined`
   → Bindings não checam se tray model está vazio
3. **Mask/Region dependendo de `parent`** — resolvido com `id: windowContent` explícito
4. **Ícones microscópicos** — 34×34px no launcher, não escalam
5. **Launcher com apenas 4 ícones visíveis** — grid clipping/overflow
6. **Settings panel ocupando espaço do grid** — layout sem responsividade

## 10. IPC Handler

```qml
IpcHandler {
    target: "dynamicIsland"
    function idle(): void
    function handle(style: string): void
    function toggleHandle(): void
    function notify(summary, message, app): void
    function media(title, artist, isPlaying, artUrl): void
    function volume(level, isMuted): void
    function brightness(level): void
}
```

Comando externo: `qs ipc call dynamicIsland.notify "Title" "Body" "App"`
