{ pkgs }:

let
  version = "1.0.0";
  # This packages the Python scripts from the repo:
  # - iris/iris.py (color extraction)
  # - mango/mango_config.py (MangoWM config CLI)
  # - quickshell/dbus-notifier.py (notification daemon)
  # - quickshell/wallhaven/wallhaven.py (Wallhaven API)
  src = pkgs.lib.cleanSourceWith {
    src = pkgs.lib.fileset.toSource {
      root = ./../../..;
      fileset = pkgs.lib.fileset.unionMany [
        (pkgs.lib.fileset.fromSource { root = ./../../..; pattern = ".config/quickshell/iris/iris.py"; })
        (pkgs.lib.fileset.fromSource { root = ./../../..; pattern = ".config/mango/mango_config.py"; })
        (pkgs.lib.fileset.fromSource { root = ./../../..; pattern = ".config/quickshell/dbus-notifier.py"; })
        (pkgs.lib.fileset.fromSource { root = ./../../..; pattern = ".config/quickshell/wallhaven/wallhaven.py"; })
      ];
    };
    filter = path: type: type != "directory";
  };
in
pkgs.python3Packages.buildPythonApplication {
  pname = "kamalen-python";
  inherit version;
  inherit src;

  propagatedBuildInputs = with pkgs.python3Packages; [
    pillow
    numpy
    pam
    requests
  ];

  # Install scripts to bin
  postInstall = ''
    mkdir -p $out/bin
    mkdir -p $out/share/kamalen-python

    # iris.py
    cp $src/.config/quickshell/iris/iris.py $out/share/kamalen-python/iris.py
    chmod +x $out/share/kamalen-python/iris.py
    ln -s $out/share/kamalen-python/iris.py $out/bin/kamalen-iris

    # mango_config.py
    cp $src/.config/mango/mango_config.py $out/share/kamalen-python/mango_config.py
    chmod +x $out/share/kamalen-python/mango_config.py
    ln -s $out/share/kamalen-python/mango_config.py $out/bin/kamalen-mango-config

    # dbus-notifier.py
    cp $src/.config/quickshell/dbus-notifier.py $out/share/kamalen-python/dbus-notifier.py
    chmod +x $out/share/kamalen-python/dbus-notifier.py
    ln -s $out/share/kamalen-python/dbus-notifier.py $out/bin/kamalen-dbus-notifier

    # wallhaven.py
    cp $src/.config/quickshell/wallhaven/wallhaven.py $out/share/kamalen-python/wallhaven.py
    chmod +x $out/share/kamalen-python/wallhaven.py
    ln -s $out/share/kamalen-python/wallhaven.py $out/bin/kamalen-wallhaven
  '';

  meta = with pkgs.lib; {
    description = "Kamalen Shell Python utilities (iris, mango-config, dbus-notifier, wallhaven)";
    homepage = "https://github.com/Guilherme4Colamarco/kamalen-shell";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}