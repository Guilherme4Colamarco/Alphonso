# Code Review — Kamalen Bar

**Scope:** files (`/home/geko/kamalen-shell/.config/quickshell/Bar.qml`, `TrayBar.qml`)
**Files reviewed:** 2 (1200 LOC total)
**Issues found:** 78 lint + 26 confirmed (deep) + 10 investigation
**Linter:** `qt_qml_lint.py` v1
**qmllint:** ran — 0 findings

---

## TL;DR — prioridade alta

1. **[D-1] `mediaVisible: false` é um literal morto** (`Bar.qml:415`). O bloco central de mídia (CAVA + play/pause + marquee + `Connections` em `mediaDisplayChanged`) é construído e nunca exibido. Isso é um **bug funcional**, não perf.
2. **[D-2] 4 `Variants` mutuamente exclusivos** (`Bar.qml:700, 745, 815, 1077`). Em dual-monitor isso instancia 8 `PanelWindow`s o tempo todo. Single-`Loader` keyed em `UIState.barMode` reduziria para 2.
3. **`UIState.borderRadius` nunca é lido em `Bar.qml`** (todos os `radius` são literais: 0/8/9/10/12/20). Slider "raio global" do Look tab não afeta a barra.
4. **TrayBar usa `Qt.rgba` cru** (`TrayBar.qml:27`) e `Bar.qml:26` redeclara `function a()` shadowando `Colors.a()`. AGENTS.md diz para usar o helper.
5. **CAVA: 12 bars × `Behavior on height` com `duration: 50`** (`Bar.qml:446`). Abaixo de qualquer preset de `Animations`, re-disparado a cada tick de áudio.

---

## Lint findings

Categorizados por regra. Detalhe linha-a-linha suprimido — execute `python3 references/lint-scripts/qt_qml_lint.py` para ver a lista completa.

| Rule | Count | Files | Notas |
|------|-------|-------|-------|
| **ORD-1** ordering | ~30 | Bar.qml | property assignment/declaration aparece após child object; id após child. Quebra o leitor. |
| **JS-1** `var` | ~15 | Bar.qml, TrayBar.qml | usar `let`/`const`. |
| **JS-2** loose equality | 2 | Bar.qml:223, 441; TrayBar.qml:40 | `==` → `===` |
| **STY-3** `anchors.*` dot | 6 sites | Bar.qml:289, 716, 762, 787, 838, 1093 | usar `anchors { … }` |
| **BND-1** `property var` | 5 | Bar.qml:20, 704, 750, 819, 1081; TrayBar.qml:21 | tipificar (int/string/etc.) |
| **BND-2** `running = true` destrói binding | 6 | Bar.qml:167, 168, 395, 402, 938, 945 | imperativo em `Process.running` quebra a binding original; OK aqui se intencional, mas documentar. |
| **PRF-1** `Rectangle { color: "transparent" }` | 2 | Bar.qml:372, 915 | usar `Item` ou `visible: false` |
| **PRF-3** `clip: true` | 3 | Bar.qml:351, 467, 904 | aceitável em Item wrapper para animar width — false-positive do lint (ver D-401). |
| **IMG-1** Image sem `sourceSize` | 1 | TrayBar.qml:35 | confirmado como issue real (ver D-3). |
| **IMP-4** import não-Qt antes de Qt | 1 | Bar.qml:1 | reordenar imports. |

---

## Deep analysis findings

### Critical (>90)

#### [D-1] `mediaVisible: false` — media center inteiro nunca aparece
- **File**: `Bar.qml:415, 412, 417, 418`
- **Category**: Bindings & Properties / Performance
- **Confidence**: 95/100
- **Finding**: `property bool mediaVisible: false` é um literal. Como nunca é imperativamente setado, o `Item` do centro tem `width: 0`, `opacity: 0`, `scale: 0.86` permanentemente. As 3 `Behavior` animations, o `Connections` em `mediaDisplayChanged` (linhas 507–514), o `marqueeAnim` e o `MouseArea mediaMa` operam sobre geometria 0×0. O usuário não vê o widget de mídia.
- **Trace**: `rg mediaVisible` retorna só a declaração e os 3 leitores. Sem `=`, sem signal emit, sem binding em `UIState.hasMedia`/`mediaState`.
- **Mitigation**: trocar para `UIState.hasMedia` ou `UIState.mediaState !== ""`. Se for intencional, deletar o subtree morto (linhas 410–546).

#### [D-2] TrayBar: Image sem error-handling, sem `sourceSize`
- **File**: `TrayBar.qml:35-41`
- **Confidence**: 92/100
- **Finding**: `Image { source: modelData.icon || ""; visible: source !== "" }` — se um SNI provider enviar uma URL/path inválida, falha silenciosa. Sem `onStatusChanged`, sem `asynchronous: true`, sem `sourceSize`. Ícones SNI típicos são 32–256px; decodar para 18px de display sem `sourceSize` é desperdício de GPU no hot path.
- **Mitigation**: `sourceSize: Qt.size(root.iconPx, root.iconPx)` + `asynchronous: true` + `onStatusChanged: if (status === Image.Error) visible = false`.

#### [D-3] 4 `Variants` mutuamente exclusivos (anti-pattern)
- **File**: `Bar.qml:700, 745, 815, 1077`
- **Confidence**: 92/100
- **Finding**: Quatro `Variants { model: Quickshell.screens; PanelWindow { visible: UIState.barMode === "X" } }`. Em dual-monitor são 8 `PanelWindow`s instanciados permanentemente. Os 3 invisíveis pagam custo de árvore de items + watchers.
- **Mitigation**: single-`Loader` com `ComponentSelector` keyed em `UIState.barMode`, ou um único `PanelWindow` com `states:` + `PropertyChanges`.

### High (80–89)

#### [D-4] `UIState.borderRadius` nunca é consumido
- **File**: `Bar.qml:721, 781, 833, 913, 1098`; `TrayBar.qml:12`
- **Confidence**: 85/100
- **Finding**: AGENTS.md diz "tiles use `br * 0.875`". Bar.qml usa literais: `radius: 0` (autohide/fixed), `12` (floating), `20` (pill), `9/10` (tags), `8` (compact tag). O slider de raio global do Look tab não muda a barra.
- **Mitigation**: substituir por `UIState.borderRadius * N` com `Behavior on radius`. Se a decisão for não usar, documentar com comentário.

#### [D-5] `function a()` local shadowa `Colors.a()`
- **File**: `Bar.qml:26`
- **Confidence**: 88/100
- **Finding**: `function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }` é idêntica a `Colors.qml:51`. Chamada 30+ vezes em Bar.qml.
- **Mitigation**: deletar, usar `Colors.a(...)` diretamente.

#### [D-6] `BarContent`/`PillBarContent` duplicam ~200 linhas
- **File**: `Bar.qml:339-406 vs 892-949` (tags), `583-636 vs 957-996` (volume), `638-675 vs 865-885` (battery)
- **Confidence**: 88/100
- **Finding**: Subtrees quase idênticos entre os dois modos. Bugfix precisa ser aplicado em dobro. Risco concreto: o bug do `Behavior on color` (D-9) já está duplicado.
- **Mitigation**: extrair `TagPill`, `VolumeBlock`, `BatteryBlock` como `component`s parametrizados.

#### [D-7] Autohide desperdiça 27px de screen real estate
- **File**: `Bar.qml:754, 760-765, 774-779`
- **Confidence**: 88/100
- **Finding**: `PanelWindow { implicitHeight: 30 }` + `peekZone` de 3px. Quando oculto, `attachedBg.y` anima para `-24` mas o layer-shell surface continua reservando 30px. O usuário perde 27px verticais permanentemente.
- **Mitigation**: animar a `implicitHeight` entre 30 e 3, ou separar `peekZone` (surface fina) de `attachedBg` (surface slide-off).

#### [D-8] TrayBar usa `Qt.rgba` cru
- **File**: `TrayBar.qml:27`
- **Confidence**: 90/100
- **Finding**: `Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.10)`. AGENTS.md diz para usar `Colors.a()`.
- **Mitigation**: `Colors.a(Colors.fg, 0.10)`.

#### [D-9] Bateria sem `Behavior on color` (BarContent + PillBarContent)
- **File**: `Bar.qml:651, 660, 872, 880`
- **Confidence**: 95/100
- **Finding**: `batColor()` muda entre `Colors.green/accent/red/yellow/fg` reativamente mas o `Text.color` não tem `Behavior` — snap em vez de animar. O Text de volume (linhas 597–611) tem Behavior; o de bateria não. Inconsistente.
- **Mitigation**: `Behavior on color { ColorAnimation { duration: Animations.fast } }` em ambos os textos.

#### [D-10] `border.color` sem Behavior em 4 locais
- **File**: `Bar.qml:374, 723-724, 917, 1100-1101`
- **Confidence**: 90/100
- **Finding**: `floatingBg`, `pillBg`, `pill tag` (×2) animam `color` mas não `border.color`. Quando `Colors.fg` muda via pipeline do iris, a borda dá snap.
- **Mitigation**: `Behavior on border.color { ColorAnimation { duration: Animations.slow } }` (mais lento que o fill para ficar orgânico).

### Medium (70–79)

#### [D-11] Hardcoded `duration: 900` no pulse da bateria
- **File**: `Bar.qml:240-241`
- **Confidence**: 85/100
- **Finding**: `NumberAnimation { duration: 900 }` ignora o profile de `Animations` (max no profile "extraslow" = 900; no "bubbly" default = 540). 1.67× mais lento.
- **Mitigation**: `Animations.xslow`.

#### [D-12] `tagSet` race sob cliques rápidos
- **File**: `Bar.qml:103, 394-403, 938-945`
- **Confidence**: 85/100
- **Finding**: `tagSet.command = [...]; tagSet.running = true` — se o processo anterior ainda está `running: true`, o re-assign de `command` é silenciosamente ignorado pelo `QProcess`. Wheel rápido na tag pode engolir `view,N` intermediários.
- **Mitigation**: in-process debounce Timer (50ms) coalescendo tag switches, ou garantir `running: false` antes de re-assign.

#### [D-13] `tagGet`/`batDetect`/`distroDetect` sem retry
- **File**: `Bar.qml:96-101, 159-172, 202-235`
- **Confidence**: 78/100
- **Finding**: One-shots sem `onExited` handler. Se `mmsg`/`ls /sys/class/power_supply` falharem no boot (subsistema ainda inicializando), estado fica preso no default até quickshell reiniciar. Inconsistente com os persistent watches que têm restart Timers.
- **Mitigation**: adicionar retry debounce (3 tentativas, 500ms) ou re-rodar a partir do debounce existente.

#### [D-14] TrayBar null-guard verbose (Qt 5 idiom)
- **File**: `TrayBar.qml:65-66`
- **Confidence**: 85/100
- **Finding**: `var qsWin = trayDelegate.QsWindow; var win = qsWin ? qsWin.window : null`. Qt 6 idiom é `trayDelegate.QsWindow?.window`. AGENTS.md diz "Always `QsWindow?.window`".
- **Mitigation**: `var win = trayDelegate.QsWindow?.window; if (win) { ... }`.

#### [D-15] CAVA: 12 `Behavior on height` com `duration: 50` hardcoded
- **File**: `Bar.qml:446`
- **Confidence**: 75/100
- **Finding**: 12 rects × animation re-targetada a cada tick de áudio (60Hz típico). `duration: 50` é menor que qualquer preset de `Animations` (min 120). 24 anim-targets por frame.
- **Mitigation**: `Animations.snap` (140) ou novo `Animations.cavaFrame`; considerar sample do decay a 30Hz.

#### [D-16] Bateria wrapper: `width` snap quando `hasBattery` flips
- **File**: `Bar.qml:640`
- **Confidence**: 75/100
- **Finding**: `width: hasBattery ? batRow.width : 0` colapsa para 0 no boot enquanto `batDetect` ainda corre. O `opacity` anima mas o `width` dá snap. Pill tags (349, 902) têm Behavior; bateria não.
- **Mitigation**: `Behavior on width { NumberAnimation { duration: Animations.medium; easing.type: Easing.OutCubic } }`.

#### [D-17] `Behavior on anchors.<margin>` + `parent.width` na mesma binding
- **File**: `Bar.qml:718, 719, 1094`
- **Confidence**: 75/100
- **Finding**: `anchors.leftMargin: barReady ? 8 : parent.width * 0.4` + `Behavior on anchors.leftMargin`. Funciona hoje (parent é PanelWindow constante), mas acopla layout animation a um `parent.width` lookup que re-evalua a cada resize.
- **Mitigation**: `readonly property real closedMargin: parent.width * 0.4; anchors.leftMargin: barReady ? 8 : closedMargin`.

#### [D-18] Polling Procs sem `onExited` fallback
- **File**: `Bar.qml` (wifiProc, ethProc, btProc, batProc)
- **Confidence**: 70/100
- **Finding**: Persistent watches têm restart Timer (✓). Polling procs são re-kicked pelos debounces, mas se `bluetoothctl`/`nmcli` derem hang, o signal source morre e o debounce nunca mais dispara.
- **Mitigation**: `onExited: <name>Debounce.restart()` em cada polling Proc.

### Low (60–69)

#### [D-19] `function onNotificationReceived(nid, app, title, body)` — signature não validada
- **File**: `Bar.qml:264`
- **Confidence**: 70/100
- **Finding**: 4 params posicionais. Se o signal em `UIState` tiver aridade diferente, Qt vai warn no runtime. Nenhum param é usado no body.
- **Mitigation**: drop params: `function onNotificationReceived() { showAttached() }`.

#### [D-20] `Icons` em Bar (PillBarContent duplica `BarContent`)
- **File**: `Bar.qml` (ver D-6 acima)
- **Confidence**: 65/100
- **Finding**: Padrão de "duas implementações do mesmo widget" é a maior fonte de bugs estruturais do arquivo.
- **Mitigation**: ver D-6.

#### [D-21] `console.error` no `parseTagOutput` de hot stream
- **File**: `Bar.qml:47`
- **Confidence**: 85/100
- **Finding**: `console.error("Failed to parse mmsg output:", e, "Data:", data)` roda em todo `SplitParser.onRead` do `tagWatch` (permanente). `mmsg` emitindo linha parcial em restart spama o journal.
- **Mitigation**: `console.warn` ou rate-limit (primeiros 3).

#### [D-22] IDs não usados
- **File**: `Bar.qml:285, 715, 775, 830, 853, 1092`
- **Confidence**: 90/100
- **Finding**: `id: barContent`, `id: floatingBg`, `id: attachedBg`, `id: fixedBg`, `id: pillBg` — todos têm 0 referências (`grep "X\."` retorna nada).
- **Mitigation**: remover. `id: root` na pill (853) também não é referenciado.

---

## Investigation targets (verificação humana)

1. **[I-1] `startDelay` re-arma em todo wallpaper change** (Bar.qml:244-249, 65%) — `running: Colors.revision >= 0` é sempre true; cada increment do `Colors.revision` restart o Timer. Hoje no-op, mas frágil.
2. **[I-2] `lit`/`*_hov` deveriam ser `readonly`** (Bar.qml:566, 577, 684, 694, 1029, 1039, 1049, 1070; 70%) — pure bindings, nunca imperativamente escritos.
3. **[I-3] `Compact: false` redundante** (Bar.qml:735; 60%) — `BarContent { compact: false }` re-afirma o default.
4. **[I-4] Layout sem awareness cross-area** (Bar.qml:293, 410, 548; 75%) — left/center/right areas não conhecem larguras uma da outra; em monitor estreito podem overlap horizontal.
5. **[I-5] CAVA color binding 4-branch** (Bar.qml:441-445; 70%) — 4 ternários + 2 `Qt.rgba` por bar × 12 × 60Hz.
6. **[I-6] `Behavior on color` em hover-state** (14 ocorrências; 65%) — hover events disparam ColorAnimation continuamente. Aceitável para UX, mensurável em profiling.
7. **[I-7] `marqueeAnim` restart em todo track change** (Bar.qml:507-514; 65%) — `stop+start+unitWidth re-eval` por mudança de faixa. Raro, mas acontece.
8. **[I-8] `parseTagOutput` error rate-limit** (relacionado a D-21) — primeira falha vs contínua.
9. **[I-9] CAVA height binding chain** (Bar.qml:433-448) — altura anim compete com color binding no mesmo delegate. Otimização: split em `readonly property real h` + `Behavior on h` apenas.
10. **[I-10] Layout anchor chain to `media center Item`** (Bar.qml:412-418) — se D-1 for corrigido, mouse events começam a propagar para `mediaMa` que hoje está em 0×0. Verificar z-order com tags/wifi.

---

## Resumo por categoria

| Categoria | Lint | Confirmed | Investigation | Total |
|-----------|------|-----------|---------------|-------|
| Imports | 1 | 0 | 0 | 1 |
| Ordering | ~30 | 0 | 0 | ~30 |
| Bindings | 11 | 4 | 2 | 17 |
| Anchors/Layout | 6 | 4 | 1 | 11 |
| JS (var/==) | ~17 | 0 | 0 | ~17 |
| Performance | 5 | 6 | 4 | 15 |
| Style | 6 | 1 | 0 | 7 |
| Component/Lifecycle | 0 | 5 | 1 | 6 |
| Image | 1 | 1 | 0 | 2 |
| **Total** | **~78** | **26** | **10** | **~114** |

Findings abaixo de confidence 60 foram suprimidos.

---

## Recomendações de ação (ordem de ROI)

1. **D-1 (mediaVisible)** — bug real, fix 1-line. Maior impacto.
2. **D-9 + D-10 (Behavior on color/border.color)** — 6 sites, copy-paste fix, visível no wallpaper change.
3. **D-8 + D-5 (Qt.rgba → Colors.a)** — delete 1 function + 1 line. Limpa convenção.
4. **D-2 (TrayBar Image)** — 3 properties add. Quick win.
5. **D-4 (UIState.borderRadius)** — decidir: usar ou documentar.
6. **D-3 / D-6 (Variants + duplication)** — refactor maior, batch separado.
7. **D-21 (console.error spam)** — 1-line. Win operacional.
8. **D-22 (unused ids)** — limpeza mecânica.

Lints ORD-1, JS-1, JS-2, STY-3, BND-1, BND-2 são cosméticos e podem ser endereçados em uma pass de `qmllint --fix` se disponível, ou em batches mecânicos.
