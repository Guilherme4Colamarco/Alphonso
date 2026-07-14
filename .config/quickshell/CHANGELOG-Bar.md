# Bar.qml — Changelog de Remodelação

Registro incremental de mudanças. Cada entrada = uma fase testada e funcionando.

---

## Fase 0 — Polish de interatividade (pré-refactor)
**Data:** 5 jul 2026

| Widget | Mudança |
|---|---|
| WiFi | Text morto → click toggle on/off + hover circle accent/red |
| Bluetooth | Text morto → click power toggle + hover circle |
| Volume | Adicionado hover scale + underline accent (consistente com clock) |
| Battery | `batMa` dead code → click abre dashboard |

---

## Fase 2 — Tray refactor + PopupBase (inspirado no meloworld-dotfiles)
**Data:** 5 jul 2026

**Problema:**
- Tray inline duplicado em Bar.qml e IslandContent.qml (~100 linhas × 2)
- `TrayPopup.qml` tinha bug crítico: `visible` binding lutava com WM para fechar, `onClosed()` nunca chamado
- `TrayState.hide()` não limpava `activeItem` (memory leak)
- `QsWindow.window` acessado sem null-guard → crash potencial

**Solução:**
1. **PopupBase.qml** — componente base com state machine (`closed`→`open`→`closing`→`closed`), slide-down + fade animado, auto-dismiss timer, estética Kamalen (Colors/Animations/UIState)
2. **TrayState.qml** — `hide()` limpa `activeItem` + `parentWindow`; adicionado `closeAll()`
3. **TrayPopup.qml** — reescrito usando `PopupBase`; `visible` controlado por `animState` (não binding); conectado a `onAboutToHide`
4. **TrayBar.qml** — componente extraído (80 linhas), configável (`iconPx`, `itemPx`, `itemH`, `itemRadius`, `itemSpacing`), null-safe `QsWindow?.window`
5. **Bar.qml / IslandContent.qml** — substituídos por `TrayBar {}`
6. **qmldir** — registrado `PopupBase` e `TrayBar`

**Resultado:**
- Código duplicado eliminado (~180 linhas)
- Tray popup fecha corretamente (clique fora, auto-dismiss 3s)
- Memory leak corrigido
- Crash potential eliminado
- Configuração consistente entre barra e island

---

## Fase 2b — Bugfix: PopupBase crash (onAboutToHide inexistente)
**Data:** 5 jul 2026

**Problema:**
- `PopupBase.qml` usava `onAboutToHide` que não existe em `PopupWindow`
- Verificado via qmltypes: `ProxyPopupWindow` não exporta esse signal
- Resultado: shell crashava ao recarregar

**Solução:**
- Removido `onAboutToHide: { animState = "closing" }`
- Fechamento já é tratado por `TrayPopup.Connections` → `animState = "closing"`
- `mask: Region { item: innerRect }` mantido (válido — `Quickshell/Region 0.0`)

**Resultado:**
- Shell recarrega sem crash
- Tray popup funciona: abre via TrayBar, fecha via auto-dismiss / clique fora

---

## Fase 1 — PillButton component (DRY refactor)
**Data:** 5 jul 2026

**Problema:** Padrão hover-circle (Item + Rectangle + Text + MouseArea = ~33 linhas) duplicado 4× (WiFi, BT, Power, Dashboard).

**Solução:** Componente `PillButton.qml` reutilizável (58 linhas, API limpa).

**Migração:**
- ✅ WiFi → PillButton (37→9 linhas)
- ✅ Bluetooth → PillButton (33→9 linhas)
- ✅ Power → PillButton (34→9 linhas)
- ✅ Dashboard → PillButton (34→9 linhas)

**Resultado:**
- Bar.qml: 958 → 868 linhas (−90)
- 4 instâncias de PillButton, zero código duplicado
- Registrado em `qmldir` como `PillButton 1.0`
- API: `icon`, `iconSize`, `active`, `activeColor`, `inactiveColor`, `hoverColor`, `activeOpacity`, `inactiveOpacity`, signal `clicked(mouse)`

**PillButton API:**
```qml
PillButton {
    icon: wifi ? "󰤨" : "󰤭"
    iconSize: 13
    active: wifi
    activeColor: Colors.accent
    inactiveColor: Colors.fg
    hoverColor: Colors.accent     // cor do bg circle no hover
    onClicked: wifiToggle.running = true
}
```

---

---

## Fase 3 — Pill/island bar mode + Dashboard tabs
**Data:** 6 jul 2026

**Problema:**
- Barra só tinha estilos full-width (`fixed`, `floating`, `autohide`)
- Usuário queria um modo "pill/island" centralizado, compacto, como no reddit r/hyprland
- Dashboard era uma coluna monolítica; difícil achar configurações

**Solução:**
1. **Bar.qml — modo `pill`**
   - Novo `barMode: "pill"` (ciclo: fixed → floating → autohide → pill)
   - `PillBarContent` component: pill centralizado, largura ajustada ao conteúdo
   - Layout: bateria + WiFi | tags 1-5 | BT + volume + clock + dashboard
   - Fontes e espaçamento reduzidos; tags menores (14×14)
   - Background com `radius: 14`, borda sutil, animação de entrada
2. **Dashboard.qml — abas**
   - Tab bar com 5 abas: Quick, Display, Media, System, Look
   - **Quick:** quick-settings grid + notificações
   - **Display:** brilho, blur, border radius
   - **Media:** volume, animações
   - **System:** uptime, power mode, bar mode
   - **Look:** tema dark/light, transparência, avatar
   - Novos componentes reutilizáveis: `TileButton`, `InfoRow`
3. **UIState.qml**
   - `barMode` agora aceita `"pill"`
   - save/load atualizados

**Resultado:**
- Estilo pill/island funcional e centralizado
- Dashboard organizado por categorias
- Ciclo de bar mode inclui pill

---

## Fase 3b — Ajuste de tamanho da barra pill
**Data:** 6 jul 2026

**Mudança:**
- Aumentada barra pill: 56px de altura total, pill de 40px
- Fontes e ícones aumentados (10–14px)
- Tags maiores (20×20) e espaçamento mais confortável
- Margens internas e externas maiores

**Resultado:**
- Barra pill mais legível e visualmente próxima à referência

---

## Fase 8 — Configuração do MangoWM pelo shell (Phase 1)
**Data:** 6 jul 2026

**Objetivo:** Permitir configurar o MangoWM diretamente pela interface do shell, com aplicação ao vivo.

**Solução:**
1. **Backend Python `~/.config/mango/mango_config.py`**
   - Parser/writer robusto do formato `key=value` do MangoWM
   - CLI: `get`, `set`, `set-apply`, `apply`, `set-many`, `set-module`, `reload`, `validate`, `migrate`
   - Preserva comentários e ordem nos arquivos
   - Detecta socket do Mango automaticamente via `MANGO_INSTANCE_SIGNATURE` ou glob
2. **Configuração modular do Mango**
   - `config.conf` passou a conter apenas `source=conf.d/*.conf`
   - Cada categoria em seu próprio arquivo: `gaps.conf`, `borders.conf`, `blur.conf`, `shadows.conf`, `animations.conf`, `colors.conf`, `focus.conf`, `input-*.conf`, `binds.conf`, `windowrules.conf`, `monitors.conf`, etc.
   - Backup automático do `config.conf` original
3. **Singleton QML `MangoConfig.qml`**
   - Registrado em `qmldir`
   - Propriedades reativas: gaps, borders, blur, shadows, opacity, input, focus
   - `MangoConfig.set(key, value)` persiste + aplica ao vivo via `mmsg setoption`
   - `MangoConfig.setModule(module, pairs)` para updates em lote
4. **Refactor de `UIState.qml`**
   - `setBorderRadius`, `applyMangoAnimations`, `applyMangoBlur`, `updateMangoOpacity`, `updateMangoBorderColors` agora usam o backend Python em vez de `sed -i` frágil
   - Isso torna compatível com a configuração modular e permite chaves novas

**Resultado:**
- MangoWM configurável programaticamente pelo shell
- Aplicação ao vivo sem recarregar tudo (para options que suportam `setoption`)
- Base pronta para a aba "Mango" no Dashboard (Phase 2)
- Validação `mango -p` limpa após remover entradas stale

---

## Fase 9 — Aba "Mango" no Dashboard (Phase 2)
**Data:** 6 jul 2026

**Objetivo:** Refatorar o Dashboard monolítico em tabs separadas e adicionar uma aba completa para configurar o MangoWM visualmente.

**Solução:**
1. **Refatoração do `Dashboard.qml` (~1100 → ~650 linhas)**
   - Replaced cinco inline `Column`s por `StackLayout`
   - Array de tabs expandido para 6 entradas (Quick, Display, Media, System, Look, Mango)
   - Lógica compartilhada (uptime, power mode, avatar picker, helpers) permaneceu no Dashboard
2. **Novos arquivos em `tabs/`**
   - `QuickTab.qml`, `DisplayTab.qml`, `MediaTab.qml`, `SystemTab.qml`, `LookTab.qml`, `MangoTab.qml`
   - Cada tab encapsula seu próprio estado e processos
3. **Componentes reutilizáveis em `components/`**
   - `ConfigSection` — seção colapsável
   - `ConfigSlider` — slider com apply no release
   - `ConfigToggle` — switch
   - `ConfigSpinner` — ciclo de valores
   - `ConfigColorRow` — picker de cor no formato Mango (`0xRRGGBBAA`)
   - `TileButton`, `InfoRow`, `SliderRow` — extraídos do Dashboard
4. **Aba `MangoTab.qml`**
   - Scrollável (`Flickable` + `Column`)
   - Seções colapsáveis: Tiling, Blur, Shadows, Opacity, Input, Focus, Animations, Colors
   - Todos os controles ligados a `MangoConfig` e aplicam ao vivo via `MangoConfig.set()`
5. **`qmldir` atualizado**
   - Registrados todos os novos tabs e componentes

**Resultado:**
- Dashboard modular e mais fácil de manter
- Aba "Mango" funcional com aplicação ao vivo de gaps, borders, blur, shadows, opacity, input, focus, animations e colors
- QuickShell recarregado e validado sem erros de QML

---

## Fase 10 — Editores de Binds, Window Rules e Monitors no Dashboard
**Data:** 6 jul 2026

**Objetivo:** Permitir gerenciar binds, window rules e configuração de monitores do MangoWM diretamente pelo Dashboard, com persistência e aplicação ao vivo.

**Solução:**
1. **Dashboard.qml expandido para 9 abas**
   - Tabs: Quick, Display, Media, System, Look, Mango, Binds, Rules, Monitors
   - Largura dos tabs ajustada dinamicamente ao número total de abas
2. **Novos arquivos em `tabs/`**
   - `BindsTab.qml` (391 linhas) — editor de binds, mousebinds, axisbinds e gesturebinds
   - `WindowRulesTab.qml` (220 linhas) — editor de window rules
   - `MonitorsTab.qml` (343 linhas) — editor de monitor rules
3. **API de directives em `MangoConfig.qml`**
   - `listDirectives(module, callback)` — retorna lista indexada de directives
   - `addDirective(module, prefix, value)` — adiciona nova directive
   - `removeDirective(module, index)` — remove directive pelo índice
   - Usa `Process` separado (`dirProc`) para evitar race conditions
4. **Backend Python `mango_config.py`**
   - Novos comandos: `cmd_list_directives`, `cmd_add_directive`, `cmd_remove_directive`
   - Filtro por prefixo (`bind`, `windowrule`, `monitorrule`, etc.)
   - Preserva comentários e linhas vazias
   - Chama `reload_config` automaticamente após add/remove
5. **BindsTab**
   - Lista todas as directives de `binds.conf`
   - Formulário "Add Bind" com key, action, tipo (bind/mousebind/axisbind/gesturebind)
   - Delete com hover vermelho + clique
6. **WindowRulesTab**
   - Lista `windowrule=` directives
   - Formulário "Add Rule" com string crua da regra
   - Seção "Examples" colapsada com regras comuns prontas para copiar
7. **MonitorsTab**
   - Lista `monitorrule=` directives
   - Formulário "Add Monitor" com name, width, height, refresh, scale, x, y
   - Formato serializado: `name:NAME,width:W,height:H,refresh:Hz,x:X,y:Y,scale:S`

**Resultado:**
- Dashboard gerencia binds, window rules e monitors sem editar arquivos manualmente
- Aplicação ao vivo via `reload_config` do MangoWM
- Audit completo dos 3 novos tabs (BindsTab, WindowRulesTab, MonitorsTab)

---

## Fase 11 — Motor de skins, materiais e cores adaptativas
**Data:** 13 jul 2026

**Objetivo:** Substituir os presets puramente geométricos por skins capazes de definir a linguagem visual completa do shell e dos widgets GTK, preservando o Iris como fonte adaptativa de cores.

**Solução:**
1. `Skins.qml` centraliza geometria, densidade, materiais, relevo, textura e raio do MangoWM.
2. `MaterialSurface`, `MaterialButton` e `MaterialTrack` formam a base reutilizável das superfícies do shell.
3. Primeiras skins: Kamalen e Commonality (CDE/Motif, compacta, quadrada, texturizada e com bevel).
4. Cores agora oferecem modos automático, preset adaptativo e preset fixo com Catppuccin, Gruvbox, Nord e Solarized.
5. O Iris publica a paleta bruta; `theme_engine.py` resolve e publica atomicamente a paleta efetiva usada por shell, GTK, Starship e SDDM.
6. O gerador GTK aplica materiais a widgets comuns sem criar decoração de janela ou dock.

**Resultado:**
- Barra, janela de configurações, popups e controles compartilhados respondem à skin ativa.
- A skin substitui o antigo seletor de formatos; movimento e blur continuam dimensões independentes.
- Commonality pode sugerir Solarized adaptativo sem trocar cores silenciosamente.
- Escala global e navegação Vim permanecem disponíveis na seção Interface.

---

## Fase 12 — Interação, layers e lifecycle refinados
**Data:** 13 jul 2026

**Objetivo:** Tornar o shell mais previsível no uso diário, acessível por teclado e robusto durante recargas.

**Solução:**
1. Um bridge IPC multiplexa os eventos de launcher, dashboard, settings, mídia, clipboard, layouts, energia, wallpaper e lock em um único watcher.
2. Processos persistentes agora rodam em grupos supervisionados e são encerrados com seus descendentes quando o QuickShell sai.
3. Estado e estatísticas de aplicativos passam por escrita JSON atômica, eliminando arquivos parciais em interrupções.
4. Dashboard e calendário ganharam layer fullscreen transparente, clique externo para fechar e foco explícito de teclado.
5. Overlays transitórios são mutuamente exclusivos; abrir um fecha os demais sem acumular layers.
6. Dashboard oferece navegação por `1/2/3`, setas ou Vim, `Esc`, `?`, botão de ajuda e uma referência visual dos atalhos globais.
7. Settings aceita `Ctrl+1…5`, `Ctrl+Tab`, `Ctrl+W`, `Esc` e mantém a navegação Vim opcional.
8. Botões, toggles e sliders compartilhados ganharam foco visível, semântica de acessibilidade e operação completa por teclado.
9. A geometria das superfícies ativas agora vem da skin; o antigo controle paralelo de arredondamento saiu da Dashboard.
10. Todos os modos da barra usam uma borda dinâmica ligada à mesma cor adaptativa do foco das janelas Mango.

**Resultado:**
- Menos processos e nenhum novo watcher órfão após fechar ou recarregar o shell.
- Popups não se sobrepõem silenciosamente e podem ser descartados pelo teclado ou por clique externo.
- Operação diária mais rápida por atalhos, com descoberta dentro da própria interface.
- Barra e janelas acompanham juntas a paleta automática do wallpaper.

---

## Fase 13 — Aqua 2009 e materiais skeuomórficos
**Data:** 13 jul 2026

**Objetivo:** Adicionar duas skins completas ao motor visual sem congelar a paleta do usuário nem invadir o escopo futuro de decoração de janelas e docks.

**Solução:**
1. Referências do r/unixporn orientaram Aqua 2009 (metal escovado, vidro e gloss) e Skeuos Workshop (madeira, papel/couro e metal físico).
2. `Skins.qml` agora possui receitas próprias para as duas skins, com geometria, textura, brilho, linha interna, ferragens e raio Mango independentes.
3. Skeuos usa papéis semânticos (`wood`, `paper`, `metal`) para evitar uma textura única aplicada indiscriminadamente em toda a interface.
4. `MaterialSurface` resolve material por função e mantém cada preview isolado da skin ativa.
5. Texturas SVG monocromáticas tonalizam a paleta efetiva do Iris em vez de introduzir cores estáticas.
6. O GTK recebeu materiais completos para botões, entradas, listas, cards, sliders, progressos, switches e scrollbars; nenhuma titlebar ou dock foi criada.
7. Nord e Gruvbox aparecem apenas como sugestões adaptativas opcionais para Aqua e Skeuos, respectivamente.

**Resultado:**
- Aqua apresenta superfícies frias, escovadas e glossy em shell e GTK.
- Skeuos diferencia estrutura de madeira, conteúdo fibroso e controles metálicos, sem repetir o visual Commonality com ornamentos decorativos.
- O modo automático continua sendo preservado ao trocar de skin; aplicar a paleta sugerida exige ação explícita.
- CSS GTK 3/4, previews e recipes passam pelos testes de integração e validação visual isolada.

---

## Fase 14 — Paleta GTK consistente e documentação operacional
**Data:** 14 jul 2026

**Objetivo:** Eliminar a divergência visual em que widgets GTK usavam cores
legadas enquanto Shell e materiais já respondiam à paleta efetiva do wallpaper;
registrar o funcionamento atual e as próximas validações sem manter um roadmap
histórico impreciso no changelog.

**Solução:**
1. `gtk_theme.py` passa a gerar a família completa de cores semânticas GTK,
   incluindo variantes de sidebar, diálogo, headerbar e estados.
2. A regeneração remove somente `@define-color` gerenciadas legadas do
   `gtk.css` raiz e preserva CSS personalizado do usuário.
3. A raiz GTK tornou-se novamente apenas o import das camadas de cores e
   materiais geradas, impedindo que azul antigo sobrescreva a paleta atual.
4. Foram adicionados testes de migração/idempotência e renderização de referência
   em GTK 3.
5. README, arquitetura, guia atual, ADR, TODO e galeria de screenshots agora
   descrevem Dashboard, Settings, skins, teclado, monitor preview e limites de
   escopo atuais.

**Resultado:**
- Thunar e outros widgets GTK passam a usar a mesma paleta efetiva do Shell.
- Usuários podem manter regras GTK próprias sem reintroduzir cores Kamalen
  antigas.
- As pendências atuais vivem em `docs/TODO.md`; o changelog permanece histórico.

---

## Próximas validações

Consulte [docs/TODO.md](../../docs/TODO.md) para a lista priorizada, incluindo
capturas de demonstração, teste físico multi-monitor, aceitação GTK por skin e
revisão de barra em telas estreitas. Titlebars e docks permanecem fora do escopo
do motor de skins atual.
