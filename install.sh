#!/bin/bash

cd "$(dirname "$0")"

[[ ! -f /etc/arch-release ]] && echo "this is for arch btw" && exit 1
[[ ! -d .config ]] && echo "can't find .config" && exit 1

install_deps() {
  sudo pacman -S --needed \
    kitty \
    cava \
    fastfetch \
    starship \
    grim \
    slurp \
    mpd \
    mpc \
    mpv \
    ffmpeg \
    swayidle \
    wlr-randr \
    gammastep \
    ttf-jetbrains-mono-nerd \
    alsa-utils \
    networkmanager \
    bluez \
    bluez-utils \
    pipewire \
    wireplumber \
    brightnessctl \
    playerctl \
    imagemagick \
    python \
    python-pillow \
    python-pam \
    inotify-tools \
    neovim \
    meson \
    ninja \
    wayland-protocols \
    wlroots \
    scenefx \
    libinput \
    seatd \
    xorg-xwayland \
    pixman \
    glslang \
    libglvnd \
    libxkbcommon || exit 1

  local aur_helper=""
  if command -v yay &>/dev/null; then
    aur_helper="yay"
  elif command -v paru &>/dev/null; then
    aur_helper="paru"
  fi

  if [[ -n "$aur_helper" ]]; then
    $aur_helper -S --needed \
      quickshell-git \
      awww-git \
      mpvpaper \
      rmpc \
      mpd-mpris \
      tiramisu \
      gpu-screen-recorder \
      pokemon-colorscripts-go || echo "some aur packages failed, continuing"
  else
    echo "no aur helper found (yay/paru)"
    echo "install manually: yay -S quickshell-git awww-git mpvpaper rmpc mpd-mpris tiramisu gpu-screen-recorder pokemon-colorscripts-go"
  fi

  install_mango_ext

  sudo systemctl enable --now NetworkManager 2>/dev/null
  sudo systemctl enable --now bluetooth 2>/dev/null
  systemctl --user enable --now mpd 2>/dev/null
  systemctl --user enable --now mpd-mpris 2>/dev/null
}

install_mango_ext() {
  echo "building mango-ext (MangoWM fork)..."

  local tmp_dir
  tmp_dir=$(mktemp -d)

  git clone https://github.com/ernestoCruz05/mango-ext.git "$tmp_dir/mango-ext" || {
    echo "failed to clone mango-ext, skipping"
    rm -rf "$tmp_dir"
    return
  }

  cd "$tmp_dir/mango-ext"
  meson setup build -Dprefix=/usr || { echo "meson setup failed"; cd - > /dev/null; rm -rf "$tmp_dir"; return; }
  meson compile -C build         || { echo "meson compile failed"; cd - > /dev/null; rm -rf "$tmp_dir"; return; }
  sudo meson install -C build    || { echo "meson install failed"; cd - > /dev/null; rm -rf "$tmp_dir"; return; }

  cd - > /dev/null
  rm -rf "$tmp_dir"

  mkdir -p ~/.config/mango-ext
  echo "mango-ext installed"
}

setup_pam() {
  if [[ ! -f /etc/pam.d/lockscreen ]]; then
    echo "setting up PAM lockscreen service..."
    echo "auth required pam_unix.so nodelay nullok
account required pam_unix.so" | sudo tee /etc/pam.d/lockscreen > /dev/null
    echo "PAM lockscreen configured"
  fi
}

install_configs() {
  mkdir -p \
    ~/.config \
    ~/.local/bin \
    ~/wallpapers \
    ~/screenshots \
    ~/screen-recordings \
    ~/.cache/wallpaper-thumbs \
    ~/.cache/wallpaper-colors \
    ~/.cache/qs \
    ~/.config/mpd/playlists \
    ~/.config/quickshell/state

  touch ~/.config/mpd/database 2>/dev/null
  touch ~/.config/mpd/state 2>/dev/null
  touch ~/.config/mpd/sticker.sql 2>/dev/null

  echo "{}" > ~/.config/quickshell/state/settings.json 2>/dev/null
  echo "{}" > ~/.config/quickshell/state/app_usage.json 2>/dev/null

  backup=~/.dotfiles-backup-$(date +%s)
  mkdir -p "$backup"

  for dir in mango mango-ext kitty quickshell fastfetch cava rmpc nvim; do
    [[ -e ~/.config/"$dir" ]] && mv ~/.config/"$dir" "$backup"/
    [[ -d .config/"$dir" ]] && cp -r .config/"$dir" ~/.config/
  done

  [[ -e ~/.config/starship.toml ]] && mv ~/.config/starship.toml "$backup"/
  [[ -f .config/starship.toml ]] && cp .config/starship.toml ~/.config/

  if [[ -d wallpapers ]] && [[ -n "$(ls -A wallpapers 2>/dev/null)" ]]; then
    cp -n wallpapers/* ~/wallpapers/ 2>/dev/null
    local first_wall
    first_wall=$(find ~/wallpapers -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.webm" \) | head -1)
    [[ -n "$first_wall" ]] && ln -sf "$first_wall" ~/wallpapers/current
  fi

  chmod +x ~/.config/quickshell/iris/iris.py 2>/dev/null

  setup_pam

  cat > ~/.local/bin/start-quickshell.sh << 'EOF'
#!/bin/bash
pkill -9 quickshell 2>/dev/null
sleep 0.3
nohup quickshell &>/dev/null &
EOF
  chmod +x ~/.local/bin/start-quickshell.sh
}

case "$1" in
  deps)
    install_deps
    echo "deps installed"
    ;;
  configs)
    install_configs
    echo "configs installed, log out and back in"
    ;;
  mango)
    install_mango_ext
    ;;
  *)
    echo "first time? [y/n]"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      install_deps
      install_configs
      echo ""
      echo "done, log out and back in"
      echo "THANK YOU FOR INSTALLING :)"
    else
      install_configs
      echo ""
      echo "configs updated, log out and back in"
    fi
    ;;
esac