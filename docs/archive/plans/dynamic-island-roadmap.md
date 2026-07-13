# Roadmap: Dynamic Island — Novos Menus & Melhorias de Design

**Projeto:** Kamalen Shell  
**Data:** 2026-07-04  
**Status:** Planejamento

---

## 🎨 Estado Atual da Ilha

A ilha hoje possui **5 modos**:

| Modo | Trigger | Conteúdo |
|---|---|---|
| `idle` (bump) | Default | Workspace + App + Clock (ou mídia compacta) |
| `idle` (peek) | Hover | Clock grande + Data + Sliders (Vol/Bright) + Wi-Fi/BT + Tray + WS dots |
| `notify` | Notificação | Ícone + App + Título + Body |
| `media` | Mídia tocando | Artwork + Título (marquee) + Artista + Progresso + Controles |
| `launcher` | Super/Search | Search bar + Grid de apps + Toggles de sistema |

---

## 🚀 Novos Menus Propostos (Prioridade)

### P0 — Essenciais

#### 1. 📋 Clipboard Manager (`mode: "clipboard"`)
**Trigger:** Super+V ou clique no tray  
**Layout:** Lista scrollável das últimas 20 entries copiadas  
**Backend:** `wl-paste --watch` + arquivo JSON em `~/.cache/qs/clipboard.json`  
**Tamanho:** 440×300  
**Features:**
- Preview truncado (primeira linha + contador de chars)
- Ícone indicando tipo (texto/link/imagem/código)
- Click → copia de volta pro clipboard
- Botão de pin (favoritos persistentes)
- Busca incremental

#### 2. 🔋 Power Menu (`mode: "power"`)
**Trigger:** Botão power no peek ou Super+Shift+Q  
**Layout:** 4 botões grandes em grid 2×2  
**Tamanho:** 300×160  
**Features:**
- Shutdown (com confirmação de 3s — undo)
- Reboot
- Suspend
- Lock + Hibernate (submenu)
- Animação de hold no botão (progress ring antes de confirmar)

### P1 — Alta Utilidade

#### 3. 🎵 Lyrics (`mode: "lyrics"`)
**Trigger:** Click no título da mídia expandida  
**Layout:** Texto scrollando sincronizado com `mediaPosition`  
**Backend:** LRCLIB API (`https://lrclib.net/api/get`) com cache local  
**Tamanho:** 440×280  
**Features:**
- Linha atual destacada (accent), próximas/posteriores com opacidade decrescente
- Auto-scroll suave
- Karaoke mode (palavra-a-palavra se timed lyrics disponíveis)
- Fallback: letra sem sync (texto estático scrollável)
- Botão para abrir letra no navegador

#### 4. 📊 Quick Stats (`mode: "stats"`)
**Trigger:** Click no clock no modo peek  
**Layout:** Grid 2×2 com métricas em tempo real  
**Tamanho:** 360×180  
**Features:**
- CPU % (uso real de `/proc/stat` via Process)
- RAM % (`/proc/meminfo`)
- GPU % (se NVIDIA: `nvidia-smi`; se AMD: `cat /sys/class/drm/card*/device/gpu_load`)
- Temperatura (sensor mais quente)
- Mini sparkline de histórico (últimos 60s, array em UIState)
- Click → abre `btop`/`htop` em Kitty

### P2 — Niceto-have

#### 5. 🖼️ Wallpaper Quick-Switch (`mode: "wallswitch"`)
**Trigger:** Click no botão "Wallpaper" do launcher panel atual  
**Layout:** Strip horizontal de thumbnails (6 visíveis, scroll pra mais)  
**Backend:** Lê `~/.cache/wallpaper-thumbs/walls.json` (já existe)  
**Tamanho:** 440×120  
**Features:**
- Thumbnail atual destacado com ring accent
- Hover → preview ampliado (popup 200×120)
- Click → aplica + fecha ilha
- Scroll → navega entre wallpapers
- Botão "Wallhaven" → abre busca online (quando implementado)

#### 6. 🔊 Audio Devices (`mode: "audio"`)
**Trigger:** Click direito no ícone de volume no peek  
**Layout:** Lista de sinks (saídas) + sources (entradas)  
**Backend:** `pactl list short sinks/sources` + `wpctl`  
**Tamanho:** 380×220  
**Features:**
- Toggle de output device (speakers ↔ headphones ↔ HDMI)
- Toggle de input device (mic selection)
- Slider individual por app (app volume mixer)
- Botão de test (beep)

#### 7. 📔 Calendar Peek (`mode: "calendar"`)
**Trigger:** Click na data no modo peek  
**Layout:** Mini-calendário do mês + próximos eventos  
**Backend:** `cal` + integração opcional com `khal`/Google Calendar  
**Tamanho:** 380×280  
**Features:**
- Grade do mês atual com dia destacado
- Indicador visual em dias com eventos
- Lista dos próximos 3 eventos abaixo
- Click num dia → expande eventos daquele dia

---

## 💎 Melhorias de Design

### Visual

#### D1. Glassmorphism Layering
- Separar `IslandSurface` em 3 camadas: **shadow → blur → surface**  
- Quando expandido, ativar blur real do QuickShell (`BlurEffect`) atrás da superfície
- Gradiente sutil de topo→base (mais escuro embaixo)
- **Impacto:** profundidade real sem custo de GPU

#### D2. Adaptive Corner Radius
- Quando idle/bump: cantos bem arredondados (`bottomRadius = height * 0.42`)
- Quando expandido: cantos moderados (`bottomRadius = UIState.borderRadius`)
- Transição suave entre os dois estados com `Behavior`
- **Impacto:** a ilha "respira" ao expandir

#### D3. Micro-sombra interna (inset shadow)
- Adicionar `Rectangle` sutil no topo interno com cor `a(Colors.bg, 0.3)` e altura 2px
- Simula inset shadow como em designs glassmorphism profissionais
- **Impacto:** polimento visual

#### D4. Accent Glow no Modo Mídia
- Quando música tocando, adicionar um `MultiEffect` com `blurEnabled: true` e `brightness: 0.3` atrás do artwork
- Cor do glow = `Colors.accent` com opacidade 0.15
- **Impacto:** o artwork "brilha" quando música ativa

### Animação

#### D5. Spring Physics no Expand/Collapse
- Trocar `NumberAnimation` por `SpringAnimation` no width/height da ilha
- `SpringAnimation { spring: 3; damping: 0.4; epsilon: 0.01 }`
- **Impacto:** animação orgânica tipo iOS Dynamic Island

#### D6. Content Crossfade com Blur
- Em vez de apenas fade opacity, adicionar blur de 4px → 0px na transição entre modos
- Usar `layer.enabled: true` + `ShaderEffect` nos containers
- **Impacto:** transições cinematográficas

#### D7. Staggered Entrance
- No modo peek, os elementos entram com stagger de 30ms cada (clock primeiro, depois data, depois sliders, depois toggles)
- Usar `Transition` com `NumberAnimation` delay incremental
- **Impacto:** sentimento de polimento

#### D8. Workspace Dots: Morphing
- Quando ativo, o dot cresce e mostra número dentro (já parcialmente implementado)
- Adicionar: quando hover num dot inativo, mostra tooltip com nome do workspace atual (`"Web"`, `"Code"`, etc)
- Adicionar: swipe gesture (3 dedos) pra trocar WS via `DragHandler`

### UX

#### D9. Contextual Long-press
- Pressionar e segurar a ilha idle → abre quick settings (peek) em modo "pinned"
- Já existe `pinnedOpen` mas sem feedback visual — adicionar indicador de pin (ícone de pino)
- **Impacto:** descobribilidade

#### D10. Keyboard Navigation
- Setas ←→ navegam entre elementos do peek
- Enter ativa elemento focado
- Tab cycle entre seções (clock → sliders → toggles → tray)
- **Impacto:** acessibilidade + power users

#### D11. Volume/Brightness OSD Refinado
- Quando showVolume/showBrightness dispara, usar o trace de perimeter atual mas adicionar:
  - Ícone grande central (ícone de volume/brightness)
  - Número grande (72pt) com a porcentagem
  - Barra de progresso circular em volta do número
- **Impacto:** feedback premium ao ajustar volume

---

## 📋 Ordem de Implementação Sugerida

| Fase | Items | Esforço | Impacto |
|---|---|---|---|
| **1 — Polimento** | D5 (spring), D7 (stagger), D2 (corners), D11 (OSD) | Médio | ⭐⭐⭐⭐⭐ |
| **2 — Essenciais** | #1 Clipboard, #2 Power | Médio | ⭐⭐⭐⭐⭐ |
| **3 — Mídia** | #3 Lyrics, D4 (artwork glow) | Alto | ⭐⭐⭐⭐ |
| **4 — Sistema** | #4 Stats, #6 Audio devices | Médio | ⭐⭐⭐⭐ |
| **5 — Visual** | D1 (glass), D3 (inset), D6 (crossfade) | Alto | ⭐⭐⭐ |
| **6 — Niceto-have** | #5 Wallpaper, #7 Calendar | Baixo | ⭐⭐⭐ |

---

## 🔧 Pre-requisitos Técnicos

- **Bug fix:** `L10n is not defined` — criar ou importar `L10n.qml`
- **Bug fix:** `expanded is not defined` no DynamicIsland linha 92 — referenciar `island.expanded`
- **Bug fix:** `launcherFocusDelay` — mover Timer pra fora do `launcherContent`
- **Nova dependência:** `wl-clipboard` para clipboard manager (provavelmente já instalado)
- **LRCLIB:** sem chave necessária, API pública
- **SpringAnimation:** disponível no Qt6/QuickShell nativamente
