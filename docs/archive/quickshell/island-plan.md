# Plano de Reescrita — Dynamic Island v2

> Baseado em: conceitos preservados ([island-concepts.md](./island-concepts.md)) e cinco referências GitHub ([island-references.md](./island-references.md)).
> Meta: substituir 3.100+ linhas monolíticas por módulos enxutos, DPI-safe, sem valores hardcoded.

## Arquitetura

### Estrutura de Arquivos (nova)

```
quickshell/
├── shell.qml                 (existing — já instancia DynamicIsland {})
├── Colors.qml                (existing singleton — Iris palette)
├── Animations.qml            (existing singleton — profile durations)
├── UIState.qml               (existing singleton — volume/media/notifications)
│
├── island/
│   ├── Island.qml            (45-60 lines) — PanelWindow + Variants + mask
│   ├── IslandState.qml       (30-40 lines) — state machine: mode, pinnedOpen, timers
│   ├── IslandShape.qml       (60-80 lines) — capsule geometry + shoulders côncavos
│   ├── IslandStyle.qml       (20-30 lines) — design tokens (sizes, radii, opacities)
│   │
│   ├── views/
│   │   ├── IdleView.qml      (40-50 lines) — clock + cava mini + tray
│   │   ├── NotifyView.qml    (30-40 lines) — app icon + summary + body
│   │   ├── MediaView.qml     (50-70 lines) — album art + title/artist + progress
│   │   ├── OsdView.qml       (20-30 lines) — volume/brightness bar
│   │   ├── LauncherView.qml  (80-100 lines) — app grid + keyboard nav
│   │   └── DashboardView.qml (60-80 lines) — toggles (wifi, bt, dnd, etc.)
│   │
│   └── widgets/
│       ├── ShoulderShape.qml (30-40 lines) — PathCubic côncavo reutilizável
│       └── CavaBars.qml      (20-30 lines) — barras de áudio (idle/media)
│
├── DynamicIsland.qml         (stub — alias para island/Island.qml, compat)
├── IslandSurface.qml         (DELETAR após migração)
└── IslandContent.qml         (DELETAR após migração)
```

**Total estimado:** ~500-650 linhas (vs 3.100+ atuais)

### Tabela de Tamanhos (design pixels, pré-sf)

| State    | w    | h   | Descrição                          |
|----------|------|-----|------------------------------------|
| strip    | 98   | 4   | linha fina (idle mínimo)           |
| bump     | 304  | 44  | pílula padrão (clock + tray)       |
| notify   | 438  | 74  | notificação com app+summary+body   |
| media    | 380  | 132 | album art + info + progress        |
| osd      | 220  | 56  | barra de volume/brightness         |
| peek     | 442  | 172 | hover/pin — preview expandido      |
| launcher | 520  | 380 | grid de apps + busca               |
| dashboard| 480  | 320 | toggles rápidos                    |

 windowHeight = dp(136) — sempre cabe bump + padding

### Design Tokens (IslandStyle.qml)

```qml
pragma Singleton
import QtQuick

QtObject {
    // DPI
    readonly property real sf: Math.max(0.65, Math.min(2.0,
        (Screen.width || 1920) / 1920))
    function dp(base: real): real { return Math.round(base * sf) }

    // Geometry
    readonly property real cornerRadius: dp(20)
    readonly property real shoulderMax: dp(20)
    readonly property real shoulderMin: dp(8)
    readonly property real padding: dp(12)
    readonly property real gap: dp(8)

    // Typography (proporção da altura da ilha, nunca hardcode)
    function fontXl(h: real): real { return Math.round(h * 0.52) }  // clock
    function fontLg(h: real): real { return Math.round(h * 0.30) }  // title
    function fontMd(h: real): real { return Math.round(h * 0.22) }  // body
    function fontSm(h: real): real { return Math.round(h * 0.16) }  // caption

    // Opacity / glass
    readonly property real glassOpacity: UIState.transparencyEnabled ? 0.72 : 1.0
    readonly property real shadowOpacity: 0.5
    readonly property real shadowBlur: 0.8
    readonly property real shadowOffset: dp(3)

    // Animation
    readonly property int morphDuration: 330
    readonly property var goeyCurve: [0.34, 1.22, 0.64, 1]
    readonly property real overshoot: 1.1
}
```

### State Machine (IslandState.qml)

```
States: "idle" | "notify" | "media" | "osd" | "peek" | "launcher" | "dashboard"

Priority (alta → baixa):
  launcher > dashboard > notify > media > osd > peek > idle

Triggers:
  - IPC: notify(), media(), volume(), brightness(), toggleLauncher()
  - Mouse: hover → peek (if idle), click → expand/collapse
  - Keyboard: Esc → close, arrows → nav (in launcher)
  - Timers: notify auto-hide 4000ms, osd auto-hide 2000ms

Transitions:
  idle → (hover) → peek → (click) → launcher/dashboard
  idle → (IPC notify) → notify → (4000ms) → idle
  idle → (IPC volume) → osd → (2000ms) → idle
  any → (Esc / click-outside) → idle
```

### PanelWindow (Island.qml)

```qml
Variants { model: Quickshell.screens }

PanelWindow {
    id: win
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:island"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    anchors.top: true
    anchors.horizontalCenter: true
    height: IslandStyle.dp(136)

    // Mask dinâmico: full-screen quando open, pill-shaped quando idle
    mask: Region { item: IslandState.isOpen ? win : islandShape }

    // Keyboard focus quando launcher/dashboard
    WlrLayershell.keyboardFocus:
        IslandState.mode === "launcher" || IslandState.mode === "dashboard"
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Click-catcher fullscreen (atrás da ilha)
    MouseArea {
        id: clickCatcher
        anchors.fill: parent
        z: 0
        enabled: IslandState.isOpen
        onClicked: IslandState.close()
    }

    // A ilha propriamente
    IslandShape {
        id: islandShape
        z: 20
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: IslandStyle.dp(8)

        // Width/Height reagem ao state
        width: IslandStyle.dp(IslandState.currentSize.w)
        height: IslandStyle.dp(IslandState.currentSize.h)

        Behavior on width {
            NumberAnimation {
                duration: IslandStyle.morphDuration
                easing.type: Easing.OutBack
                easing.overshoot: IslandStyle.overshoot
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: IslandStyle.morphDuration
                easing.type: Easing.OutBack
                easing.overshoot: IslandStyle.overshoot
            }
        }

        // Content via Loader (performance)
        Loader {
            anchors.fill: parent
            anchors.margins: IslandStyle.padding
            sourceComponent: {
                switch (IslandState.mode) {
                    case "idle":      return idleComp
                    case "notify":    return notifyComp
                    case "media":     return mediaComp
                    case "osd":       return osdComp
                    case "peek":      return peekComp
                    case "launcher":  return launcherComp
                    case "dashboard": return dashboardComp
                }
            }
        }
    }
}
```

### Shape Geometry (IslandShape.qml)

```
┌─────────────────────────────────────────┐
│╲ shoulder                       shoulder╱│  ← cantos superiores côncavos
│ ╲___________________________________╱    │  ← flush com topo da tela
│                                         │
│              [ content ]                 │
│                                         │
└─────────────────────────────────────────┘  ← bottom rounded (cornerRadius)
```

- Top corners: quadrados (flush com borda superior da tela)
- Bottom corners: `cornerRadius`
- Shoulders: PathCubic com control points que curvam para dentro
- Background: `Colors.surface` com `IslandStyle.glassOpacity`
- Border: 1px `Colors.a(Colors.fg, 0.08)`
- Shadow: `MultiEffect { shadowEnabled: true; shadowBlur: 0.8; shadowOpacity: 0.5 }`

### Content Views

**IdleView** — Relógio (fontXl), data (fontSm), tray icons (height*0.45), cava bars quando música tocando

**NotifyView** — App icon (h*0.35) + summary (fontLg, bold) + body (fontSm, dim). Auto-hide 4s.

**MediaView** — Album art quadrado (h*0.72) + title/artist (fontMd/fontSm) + progress bar animada

**OsdView** — Ícone + barra horizontal. Auto-hide 2s. SmoothedAnimation para progress.

**LauncherView** — Grid 5×N de apps, busca por texto, Setas/Enter/Esc

**DashboardView** — Toggle buttons (WiFi, BT, DnD, Volume slider, Brightness slider)

### IPC Handler (preservar compatibilidade)

```qml
IpcHandler {
    target: "dynamicIsland"
    function idle(): void         { IslandState.toIdle() }
    function notify(s,m,a): void  { IslandState.notify(s,m,a) }
    function media(t,ar,p,art): void { IslandState.media(t,ar,p,art) }
    function volume(l,m): void    { IslandState.osd("volume", l, m) }
    function brightness(l): void  { IslandState.osd("brightness", l) }
    function toggleLauncher(): void { IslandState.toggle("launcher") }
}
```

## Ordem de Implementação

### Fase 1: Fundação (IslandStyle + IslandState + Island.qml)
1. Criar `island/IslandStyle.qml` — tokens + dp()
2. Criar `island/IslandState.qml` — state machine + size map
3. Criar `island/Island.qml` — PanelWindow + mask + Loader vazio
4. Registrar singletons no `qmldir`
5. Testar: ilha deve aparecer como retângulo transparente no topo

### Fase 2: Shape (IslandShape + ShoulderShape)
6. Criar `island/IslandShape.qml` — capsule com shoulders
7. Adicionar background glass + shadow + border
8. Testar: capsule visível com transição de tamanho ao trocar state

### Fase 3: Views básicas (Idle + OSD + Notify)
9. `IdleView.qml` — clock + data + tray
10. `OsdView.qml` — barra volume/brightness
11. `NotifyView.qml` — notificação
12. IPC handler — conectar UIState → IslandState
13. Testar: `qs ipc call dynamicIsland.volume 75 false` deve mostrar OSD

### Fase 4: Views avançadas (Media + Launcher + Dashboard)
14. `MediaView.qml` — player info
15. `LauncherView.qml` — grid + keyboard nav
16. `DashboardView.qml` — toggles
17. `CavaBars.qml` — barras de áudio
18. Testar: cada view funciona via IPC e mouse

### Fase 5: Polish
19. Shoulders dinâmicos (ShoulderShape.qml)
20. Click-outside-to-close (mask switching)
21. Hover → peek
22. Limpar arquivos antigos (IslandSurface.qml, IslandContent.qml, DynamicIsland.qml)
23. DynamicIsland.qml vira stub: `Island {}`

## Riscos & Mitigações

| Risco | Mitigação |
|-------|-----------|
| Singleton registration no qmldir | Verificar `pragma Singleton` + import path |
| `Screen.width` indisponível no eval | Fallback `|| 1920` (já em IslandStyle) |
| Mask Region com item null | `IslandState.isOpen ? win : islandShape` — sempre válido |
| Multi-monitor flickering | `Variants { model: Quickshell.screens }` |
| Launcher keyboard focus | `WlrKeyboardFocus.Exclusive` condicional |
| Tray model vazio | Guard em IdleView: `model.count > 0 ? ... : null` |
| Reload do QS quebra singleton | `pragma Singleton` + init lazy |

## Manter do código atual
- ✅ IPC handler (compatibilidade)
- ✅ Cores Iris (Colors.qml)
- ✅ Animações (Animations.qml)
- ✅ UIState (volume/media/notifications já integrados)
- ✅ Goey curve [0.34, 1.22, 0.64, 1]
- ✅ Shoulders côncavos
- ✅ Keyboard navigation

## Descartar
- ❌ DynamicIsland.qml (798 linhas monolítico)
- ❌ IslandSurface.qml (shape duplicado, valores hardcoded)
- ❌ IslandContent.qml (1943 linhas, ~20 valores hardcoded)
- ❌ Valores hardcoded (29, 13, 8, 42, etc.)
- ❌ Boolean flags de state (substituir por string state)
