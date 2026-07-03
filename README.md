<div align="center">

# 🦎 Kamalen Shell

![Status](https://img.shields.io/badge/Status-Desenvolvimento-green?style=flat-square)
![WM](https://img.shields.io/badge/WM-MangoWM-e8a87c?style=flat-square)
![Wayland](https://img.shields.io/badge/Protocol-Wayland-ffbc42?style=flat-square&logo=wayland&logoColor=white)
![Engine](https://img.shields.io/badge/Colors-Iris%20Engine-89b4fa?style=flat-square)

<br>

> 🎨 **Um setup dinâmico e responsivo para MangoWM que muda de cor como um camaleão, adaptando-se a qualquer papel de parede instantaneamente.**

</div>

---

## 📢 O Conceito

A maioria dos setups/rices de Linux são feitos sob medida para funcionar com apenas um papel de parede e uma paleta de cores estática. O **Kamalen Shell** quebra essa barreira: ele foi desenhado para extrair cores de qualquer imagem que você definir como wallpaper e espalhar essa paleta dinamicamente por todo o seu sistema.

Não importa a imagem que você jogue nele, 90% das vezes ele vai gerar um tema coeso e agradável sem que você precise abrir um único arquivo de configuração. Ele também conta com 5 perfis diferentes de animação (bubbly, calm, snappy, extraslow, none) para se adaptar ao seu ritmo de uso.

---

## 🚀 O que tem de legal?

* **Extração Inteligente de Cores** — Um script em Python (`iris.py`) usa agrupamento K-Means no espaço de cores LAB para identificar os tons dominantes do papel de parede ativo. Ele gera cores de fundo, texto, acentos e até paleta de sintaxe de código, aplicando instantaneamente em:
  - **Kitty** (via socket em tempo real, sem reiniciar)
  - **Neovim** (cria um color scheme Lua dinâmico)
  - **GTK 3/4** (escreve CSS direto nas pastas de tema)
  - **MangoWM** (atualiza a cor das bordas das janelas)
  - **Starship Prompt** (sincroniza o prompt do seu terminal)

* **Seletor de Wallpaper 3D** — Chega de grades chatas. Navegue pelos seus wallpapers em um carrossel 3D cilíndrico que reproduz GIFs e vídeos na carta central. Pressione `R` para escolher um aleatório!

* **Tela de Bloqueio Integrada** — Desenhada em Quickshell, suporta wallpapers em vídeo/GIF com efeito de desfoque (blur) dinâmico, usa PAM do Python para autenticação super rápida e exibe animações em caso de senha incorreta.

* **Totalmente Modular** — Altere velocidades de animação, ligue/desligue transparências, mude o raio das bordas das janelas ou altere o estilo da barra com cliques simples no painel.

---

## 📸 Screenshots

![](./screenshots/1.png)
![](./screenshots/2.png)
![](./screenshots/3.png)
![](./screenshots/4.png)
![](./screenshots/5.png)
![](./screenshots/6.png)
![](./screenshots/7.png)
![](./screenshots/8.png)
![](./screenshots/9.png)
![](./screenshots/10.png)

---

## 🛠️ O Stack

| Componente | Ferramenta |
|---|---|
| **Window Manager** | [mango-ext](https://github.com/ernestoCruz05/mango-ext) (Fork aprimorado do MangoWM) |
| **Painéis / Widgets** | [Quickshell](https://github.com/outfoxxed/quickshell) (QML reativo) |
| **Terminal** | Kitty |
| **Editor de Texto** | Neovim |
| **Tela de Bloqueio** | Quickshell + python-pam |
| **Notificações** | Tiramisu redirecionado para o Quickshell |
| **Wallpaper Daemon** | awww-daemon |
| **Video Wallpapers** | mpvpaper |
| **Visualizador de Áudio** | Cava (12 barras de frequência) |

---

## 📥 Instalação

O script de instalação foi desenvolvido e testado no **Arch Linux** (e derivados como CachyOS).

```bash
git clone https://github.com/Guilherme4Colamarco/kamalen-shell.git
cd kamalen-shell
chmod +x install.sh
./install.sh
```

### O que o instalador faz:
- Instala todas as dependências do sistema e compila o `mango-ext` automaticamente.
- Faz backup seguro das suas configurações antigas em `~/.dotfiles-backup-<timestamp>`.
- Copia todas as configurações para a pasta `~/.config/`.
- Configura o serviço de autenticação PAM para a tela de bloqueio.
- Cria os diretórios necessários de cache e estado.

**Próximos Passos após instalar:**
1. Faça logout da sua sessão atual.
2. Na tela de login, selecione **MangoWM** (ou mango-ext).
3. Faça login.
4. Execute `~/.config/scripts/random-wallpaper.sh` para definir seu primeiro tema de cores!

---

## ✨ Recursos em Destaque

### 🎨 Extração de Cores (Iris Engine)
O script `iris.py` cuida de todo o trabalho pesado. Ele redimensiona a imagem para otimizar a velocidade, analisa a distribuição espacial das cores e gera paletas ideais (incluindo cores escuras ou claras automáticas). Tudo é salvo em cache de forma que voltar a um papel de parede anterior seja instantâneo.

### 🎞️ Perfis de Animação
Você pode mudar a personalidade do sistema no painel de controle escolhendo entre 5 perfis:
- **bubbly**: Super dinâmico, quicando e com efeitos elásticos (padrão).
- **calm**: Transições suaves e lentas estilo macOS.
- **snappy**: Rápido, seco e responsivo.
- **extraslow**: Movimentos bem cadenciados e elegantes.
- **none**: Transições instantâneas (sem animações).

### 🔒 Tela de Bloqueio
Exibe relógio, data e foto de perfil. Reproduz o mesmo vídeo ou GIF de fundo do seu desktop de forma contínua com efeito blur. Conta com indicador de comprimento de senha e animação de vibração caso erre a autenticação.
*(Nota de Segurança: Um `killall quickshell` contorna a tela de bloqueio. É um bloqueio visual e de conveniência, não um cofre de alta segurança).*

### 🖼️ Seletor de Wallpaper 3D
Ativado com `Super + W`. Use `H/L` ou as setas para rodar o cilindro de papéis de parede. Ao parar sobre um vídeo ou GIF, ele começa a tocar na tela. Pressione `Enter` para aplicar o tema e a cor do sistema mudará em menos de 2 segundos.

### 🎵 Controle de Mídia
Widget drop-down no topo central que mostra o que está tocando via `playerctl` (Spotify, Firefox, mpv, etc.). Suporta barra de progresso interativa, títulos com scroll lateral automático, e dois estilos de visualização: **Vinyl mode** (disco giratório com capa do álbum) e **GIF mode** (GIFs dinâmicos sincronizados com a música). Cava com 12 barras renderizado na base.

### 📊 Painel Geral (Dashboard)
Painel lateral direito que abriga foto de perfil, tempo de atividade do PC, menu de energia e 11 botões rápidos de controle (Wi-Fi, Bluetooth, DND, Transparências, Modos de energia, Modos de animação e raio de borda). Também centraliza as notificações organizadas e agrupadas por aplicativo.

---

## ⌨️ Atalhos Principais

| Atalho | Ação |
|---|---|
| `Super + Enter` | Abrir terminal (Kitty) |
| `Super + Shift + Enter` | Abrir terminal flutuante |
| `Super + D` | Lançador de aplicativos |
| `Super + W` | Seletor de Wallpaper 3D |
| `Super + E` | Gerenciador de Arquivos (Thunar) |
| `Super + X` | Bloquear Tela |
| `Super + M` | Maximizar/Restaurar Janela |
| `Super + Shift + Q` | Fechar janela focada |
| `Super + Shift + Espaço`| Alternar janela entre flutuante/tiling |
| `Super + F` | Tela Cheia (Fullscreen) |
| `Super + H/J/K/L` | Focar janelas (esquerda, baixo, cima, direita) |
| `Super + Shift + H/J/K/L`| Mover janelas físicas de lugar |
| `Super + CTRL + H/J/K/L` | Redimensionar janela ativa |
| `Super + 1-5` | Mudar de área de trabalho |
| `Super + Shift + 1-5` | Enviar janela para outra área de trabalho |
| `Super + T` | Layout Tiling (Dwindle) |
| `Super + Shift + T` | Layout Tiling (Tile clássico) |
| `Super + C` | Layout Canvas (Área infinita) |
| `Super + S` | Layout Scroller (Páginas horizontais) |

---

## 📂 Estrutura de Arquivos

```
~/.config/quickshell/
├── iris/iris.py              # Script principal de extração de cores
├── state/
│   ├── settings.json         # Persistência de configurações ativas
│   └── app_usage.json        # Frequência de uso de apps para o launcher
├── assets/
│   ├── pfps/                 # Avatares de perfil
│   └── gifs/                 # GIFs animados para o reprodutor de mídia
├── Colors.qml                # Singleton gerenciador de paletas
├── UIState.qml               # Gerenciador global de estados
├── Animations.qml            # Definição física dos perfis de animações
├── Dashboard.qml             # Painel de controle lateral
├── Launcher.qml              # Menu de aplicativos (Rofi-like)
├── Wallpaper.qml             # Carrossel 3D de papéis de parede
├── Music.qml                 # Reprodutor de mídia interativo
├── Calendar.qml              # Calendário e relógio da barra
├── Lockscreen.qml            # Tela de bloqueio
├── NotificationPopup.qml     # Banners de notificação flutuantes
└── Bar.qml                   # Barra de status superior

~/.config/mango/
└── config.conf               # Configurações gerais do MangoWM
```

---

## ⚠️ Problemas Conhecidos

- **Bandeja do Sistema (System Tray):** Algumas aplicações exigem que a barra seja iniciada sob uma sessão de aplicação completa Qt para os menus do clique direito renderizarem. Se a bandeja sumir ou não responder, reinicie a barra usando `quickshell & disown`.
- **Extração de cor extrema:** Imagens puramente pretas, brancas ou com gradientes excessivamente complexos podem ocasionalmente gerar cores de acento de baixo contraste. O recomendado é usar imagens fotográficas ou ilustrações bem definidas.
- **Primeiro Carregamento de Wallpapers:** A primeira inicialização do carrossel pode demorar um pouco enquanto as miniaturas (thumbnails) são geradas em cache em segundo plano.

---

## 🤝 Créditos

- **[MangoWM](https://github.com/mangowm/mango):** O compositor Wayland que serve de fundação.
- **[mango-ext](https://github.com/ernestoCruz05/mango-ext):** Pelas extensões incríveis de janelas e tiling.
- **[Quickshell](https://github.com/outfoxxed/quickshell):** O motor QML flexível por trás da barra e componentes.
- A comunidade do **r/unixporn** pelas inspirações estéticas e ideias infinitas.

---

## 📄 Licença

Este projeto está sob a licença MIT. Sinta-se livre para usar, estudar, modificar e distribuir.

<div align="center">

*Mude de papel de parede e assista a mágica acontecer. 🦎🎨*

</div>
