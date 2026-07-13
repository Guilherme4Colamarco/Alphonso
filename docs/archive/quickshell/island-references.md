# Dynamic Island — Referências de Código Humano

> Consolidado de 5 repos GitHub + padrões extraídos. 2026-07-05.

## Repos Analisados

### 1. patheonsceo/Dynamic-island-for-arch ⭐ MELHOR REFERÊNCIA
- **Estrutura:** `modules/ii/island/` com 20+ QMLs modulares
- **Abordagem:** Singleton `Island.qml` (bus de estado) + `IslandNotch.qml` (Scope com Variants)
- **States:** idle → volume/brightness → notification → media → agent → open(dashboard/launcher/power/tools/overview)
- **Shape:** notch pendurado no topo, cantos superiores quadrados (flush com tela), bottom rounded, shoulders côncavos
- **Goey curve:** `[0.34, 1.22, 0.64, 1, 1, 1]` ← **IGUAL À NOSSA!**
- **morphDuration:** 330ms
- **reservedStrip:** 40px (PanelWindow SEPARADO click-through para exclusiveZone)
- **Key patterns:**
  - `Variants { model: Quickshell.screens }` para multi-monitor
  - Full-screen window (4-anchor) com mask dinâmico → click-catcher funciona
  - `surfaceSizes` como map: `{ "dashboard": {w:1040,h:360}, "launcher":{w:560,h:380}, ... }`
  - `exclusionMode: ExclusionMode.Ignore` + `exclusiveZone: 0` (flutuante)
  - `WlrLayershell.keyboardFocus` condicional por ownsOpen
  - OSD: timer auto-hide (2000-4000ms dependendo do tipo)

### 2. enhaoswen/Tide-island
- **2255 linhas** num único DynamicIslandWindow.qml
- **States:** normal → split(OSD) → expanded(player) → control_center → wallpaper_picker → notification → lyrics → long_capsule → custom
- **Key patterns:**
  - Mask com Region union (gesture strip + capsule + detail shells)
  - `topGestureInputHeight` para input zone configurável
  - Swipe gestures: sideSwipeInteractive, swipeTransitionProgress
  - `SmoothedAnimation { velocity: 1.2; duration: 180 }` para OSD progress
  - `osdProgressAnimationEnabled` flag para desabilitar animação durante update
  - `smartRestoreState()` para voltar do expanded pro estado anterior
  - Click actions configuráveis via `handleConfiguredClickAction(actionName)`

### 3. HandsomeMJZ/quickshell-DynamicIsland
- **176 linhas** — simples e direto
- **States via boolean flags:** showDashboard, showWallpaper, showLauncher, showLyrics, expanded, showVolume
- **Prioridade via precedence chain:** `isDashboardMode → isWallpaperMode → ... → isNotifMode`
- **Key patterns:**
  - Contents como Items sobrepostos com opacity + Behavior on opacity (200ms)
  - MouseArea com left/right click (right = toggle dashboard/wallpaper/lyrics, left = expand/collapse)
  - Sizes hardcoded por state: dashW:810, wallW:810, lauW:560
  - `visible: opacity > 0` para desligar conteúdo invisível

### 4. turbogoomba/Dynamic-Bar
- **Pill hide/show com hot zone** (barra flutuante auto-hide)
- **States:** idle → hub → power → wallpaper → media → notifications → launcher
- **Key patterns:**
  - Hot zone `WlrLayershell` separado no topo (4px height) com hover detection
  - `margins.top: (barVisible || islandState !== "idle") ? 0 : -(pill.height + 20)` — desliza para cima ao esconder
  - `OutBack overshoot: 1.2` para width/height morph
  - `mask: Region { item: pill }` — mask segue o pill
  - `keyboardFocus: pill.islandState === "launcher" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand`
  - Playerctl via Process com polling timer (1s position, metadata fetch)
  - Timer auto-hide 1200ms verificando containsMouse em múltiplas windows

### 5. SergioM26/dynamic-island-bar
- **121 linhas** — minimalista
- **Key patterns:**
  - `IslandForm.qml` separa shape do conteúdo (Rectangle + radius: height/2)
  - `Behavior on implicitWidth/Height { NumberAnimation { duration: 320; easing: OutCubic } }`
  - `mask: Region { item: form }` — mask segue a forma
  - `MultiEffect` para shadow (shadowBlur: 0.8, shadowOpacity: 0.8, shadowVerticalOffset: 2)
  - `Loader` para trocar views dinamicamente
  - `exclusiveZone: 40`

## Padrões Extraídos

### PanelWindow Config (consenso entre todos)
```qml
PanelWindow {
    screen: modelData
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top        // ou Overlay
    WlrLayershell.namespace: "quickshell:island"
    exclusionMode: ExclusionMode.Ignore      // flutuante
    exclusiveZone: 0                          // não reserva espaço (ou 40 se reserva)
    anchors { top: true; left: true; right: true }  // ou full-screen
    mask: Region { item: pillShape }          // mask segue a forma
    // keyboardFocus condicional
}
```

### State Machine (3 abordagens)
1. **String state** (patheonsceo, Tide): `islandState: "idle" | "expanded" | "open" | ...`
2. **Boolean flags** (HMJZ): `showDashboard: false; expanded: false; showVolume: false`
3. **Singleton bus** (patheonsceo Island.qml): shared state across PanelWindows

### Width/Height por State
- Idle/compact: 125-200px wide, 32-40px tall
- Expanded (media/notif/volume): 180-480px wide, 40-92px tall
- Open (dashboard/launcher/overview): 320-1100px wide, 92-420px tall
- **Sempre via `Behavior on width/height` com OutBack overshoot 1.1-1.3**

### DPI Scaling (LIÇÃO PRINCIPAL)
- **patheonsceo:** Usa `Appearance.sizes.baseBarHeight`, `Appearance.font.pixelSize.smaller` — tokens centralizados
- **end-4:** `MaterialThemeLoader` gera tokens dinamicamente
- **NENHUM** usa pixelSize hardcoded — tudo via tokens
- **NOSSO BUG:** ~20 valores hardcoded (29, 13, 8, etc.) não escalam

### Click-outside-to-close (2 estratégias)
1. **Full-screen window + MouseArea** (patheonsceo): window 4-anchor transparente, MouseArea só enabled quando open
2. **Mask Region** (todos): `mask: Region { item: pillShape }` faz área fora do pill ser click-through

### Multi-monitor
- **patheonsceo + SergioM26:** `Variants { model: Quickshell.screens }`
- **Tide:** Um window por monitor com `hyprMonitorName`
- **Singleton Island.qml** coordena qual monitor tem surface open

### Animação Consensus
| Aspecto | Valor |
|---------|-------|
| Width/height morph | 320-400ms, OutBack overshoot 1.1-1.3 |
| Opacity fade | 200-250ms, OutQuad |
| OSD progress | SmoothedAnimation velocity 1.2, 180ms, InOutQuad |
| Auto-hide timer | 1200-4000ms (varia por tipo de conteúdo) |
| Goey curve | [0.34, 1.22, 0.64, 1] (patheonsceo = nosso) |

### Content Loading
- **HMJZ:** Items sobrepostos com opacity fade
- **patheonsceo:** `Loader { sourceComponent: ... }` ou `Component {}` com state switch
- **SergioM26:** `Loader` com sourceComponent
- **turbogoomba:** Items com opacity + visible condicional

### Cores
- **patheonsceo:** `IslandStyle.qml` singleton com tokens (pillColor, textColor, accent, etc.)
- **end-4:** `Appearance.colors.colLayer1` via MaterialThemeLoader
- **Tide:** `StyleTokens` + `UserConfig`
- **NÓS:** Iris (wallpaper → paleta) — manter!

## Decisões para a Reescrita

1. **State machine via string** (mais flexível que booleans)
2. **Singleton `IslandBus.qml`** para coordenar estado (como patheonsceo)
3. **`surfaceSizes` como map** para tamanhos por surface
4. **Tokens de design** (`IslandStyle.qml` singleton) — ZERO hardcoded
5. **Full-screen PanelWindow** com mask dinâmico (click-catcher funciona)
6. **reservedStrip separado** se quisermos exclusiveZone
7. **Variants multi-monitor**
8. **Loader para contents** (performance)
9. **Manter:** goey curve [0.34,1.22,0.64,1], dp() DPI-aware, shoulders côncavos, keyboard nav
10. **Iris para cores** — nossa diferenciação
