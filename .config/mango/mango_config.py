#!/usr/bin/env python3
"""
MangoWM configuration manager.

Provides a CLI to read, write, live-apply, and migrate MangoWM config files.
"""

import json
import os
import shutil
import subprocess
import sys
from collections import OrderedDict, defaultdict
from datetime import datetime
from pathlib import Path

# PORQUÊ: Caminho configurável via variável de ambiente MANGO_CONFIG_DIR.
# Fallback para ~/.config/mango (padrão XDG). Permite testes e outros usuários.
CONFIG_DIR = Path(
    os.environ.get("MANGO_CONFIG_DIR")
    or Path.home() / ".config" / "mango"
)
CONFIG_FILE = CONFIG_DIR / "config.conf"
CONF_D_DIR = CONFIG_DIR / "conf.d"

MODULE_ORDER = [
    "gaps",
    "borders",
    "opacity",
    "colors",
    "blur",
    "shadows",
    "animations",
    "layout",
    "scroller",
    "dwindle",
    "canvas",
    "overview",
    "focus",
    "input-keyboard",
    "input-mouse",
    "input-trackpad",
    "binds",
    "windowrules",
    "monitors",
    "autostart",
    "environment",
    "misc",
]

MODULE_MAPPING = {
    # gaps
    "gappih": "gaps",
    "gappiv": "gaps",
    "gappoh": "gaps",
    "gappov": "gaps",
    # borders
    "borderpx": "borders",
    "border_radius": "borders",
    "no_border_when_single": "borders",
    "no_radius_when_single": "borders",
    "border_radius_location_default": "borders",
    # opacity
    "focused_opacity": "opacity",
    "unfocused_opacity": "opacity",
    # colors
    "rootcolor": "colors",
    "bordercolor": "colors",
    "focuscolor": "colors",
    "urgentcolor": "colors",
    "scratchpadcolor": "colors",
    "globalcolor": "colors",
    "overlaycolor": "colors",
    "maximizescreencolor": "colors",
    # blur
    "blur": "blur",
    "blur_layer": "blur",
    "blur_optimized": "blur",
    "blur_params_num_passes": "blur",
    "blur_params_radius": "blur",
    "blur_params_noise": "blur",
    "blur_params_brightness": "blur",
    "blur_params_contrast": "blur",
    "blur_params_saturation": "blur",
    # shadows
    "shadows": "shadows",
    "layer_shadows": "shadows",
    "shadow_only_floating": "shadows",
    "shadows_size": "shadows",
    "shadows_blur": "shadows",
    "shadows_position_x": "shadows",
    "shadows_position_y": "shadows",
    "shadowscolor": "shadows",
    # animations
    "animations": "animations",
    "layer_animations": "animations",
    "animation_type_open": "animations",
    "animation_type_close": "animations",
    "animation_fade_in": "animations",
    "animation_fade_out": "animations",
    "tag_animation_direction": "animations",
    "zoom_initial_ratio": "animations",
    "zoom_end_ratio": "animations",
    "fadein_begin_opacity": "animations",
    "fadeout_begin_opacity": "animations",
    "animation_duration_open": "animations",
    "animation_duration_close": "animations",
    "animation_duration_move": "animations",
    "animation_duration_tag": "animations",
    "animation_duration_focus": "animations",
    "animation_curve_open": "animations",
    "animation_curve_close": "animations",
    "animation_curve_move": "animations",
    "animation_curve_tag": "animations",
    "animation_curve_focus": "animations",
    "animation_curve_opafadein": "animations",
    "animation_curve_opafadeout": "animations",
    # layout
    "new_is_master": "layout",
    "default_mfact": "layout",
    "default_nmaster": "layout",
    "smartgaps": "layout",
    "circle_layout": "layout",
    # scroller
    "scroller_structs": "scroller",
    "scroller_default_proportion": "scroller",
    "scroller_focus_center": "scroller",
    "scroller_prefer_center": "scroller",
    "edge_scroller_pointer_focus": "scroller",
    "scroller_default_proportion_single": "scroller",
    "scroller_proportion_preset": "scroller",
    # dwindle
    "dwindle_smart_split": "dwindle",
    "dwindle_preserve_split": "dwindle",
    "dwindle_vsplit": "dwindle",
    "dwindle_hsplit": "dwindle",
    "dwindle_smart_resize": "dwindle",
    # canvas
    "canvas_tiling": "canvas",
    "canvas_pan_on_kill": "canvas",
    # overview
    "enable_hotarea": "overview",
    "ov_tab_mode": "overview",
    "overviewgappi": "overview",
    "overviewgappo": "overview",
    # focus
    "xwayland_persistence": "focus",
    "focus_on_activate": "focus",
    "sloppyfocus": "focus",
    "warpcursor": "focus",
    "focus_cross_monitor": "focus",
    "focus_cross_tag": "focus",
    "enable_floating_snap": "focus",
    "snap_distance": "focus",
    "drag_tile_to_tile": "focus",
    # input-keyboard
    "repeat_rate": "input-keyboard",
    "repeat_delay": "input-keyboard",
    "numlockon": "input-keyboard",
    "xkb_rules_rules": "input-keyboard",
    "xkb_rules_model": "input-keyboard",
    "xkb_rules_layout": "input-keyboard",
    "xkb_rules_variant": "input-keyboard",
    "xkb_rules_options": "input-keyboard",
    "cursor_theme": "input-keyboard",
    "cursor_size": "input-keyboard",
    "cursor_hide_timeout": "input-keyboard",
    # input-mouse
    "mouse_natural_scrolling": "input-mouse",
    "mouse_accel_profile": "input-mouse",
    "mouse_accel_speed": "input-mouse",
    "left_handed": "input-mouse",
    "axis_scroll_factor": "input-mouse",
    # input-trackpad
    "disable_trackpad": "input-trackpad",
    "tap_to_click": "input-trackpad",
    "tap_and_drag": "input-trackpad",
    "trackpad_natural_scrolling": "input-trackpad",
    "trackpad_accel_profile": "input-trackpad",
    "trackpad_accel_speed": "input-trackpad",
    "scroll_button": "input-trackpad",
    "scroll_method": "input-trackpad",
    "click_method": "input-trackpad",
    "send_events_mode": "input-trackpad",
    "drag_lock": "input-trackpad",
    "disable_while_typing": "input-trackpad",
    "middle_button_emulation": "input-trackpad",
    "swipe_min_threshold": "input-trackpad",
    "button_map": "input-trackpad",
    "trackpad_scroll_factor": "input-trackpad",
}

# Directive prefixes grouped by module. Longer prefixes are checked first so that
# e.g. exec-once= is matched before exec=.
DIRECTIVE_MODULES = [
    (
        (
            "gesturebind=",
            "mousebind=",
            "axisbind=",
            "bind=",
        ),
        "binds",
    ),
    (("windowrule=",), "windowrules"),
    (("monitorrule=",), "monitors"),
    (("exec-once=", "exec="), "autostart"),
    (("env=",), "environment"),
]


def error(msg):
    print(json.dumps({"ok": False, "error": msg}))
    sys.exit(1)


def classify_line(line):
    """Return the module a non-comment, non-blank line belongs to, or None."""
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return None

    # Directives are matched by prefix; longer prefixes within a group are
    # listed first, but we sort each group by length descending to be safe.
    for prefixes, module in DIRECTIVE_MODULES:
        for prefix in sorted(prefixes, key=len, reverse=True):
            if stripped.startswith(prefix):
                return module

    if "=" in stripped:
        key = stripped.split("=", 1)[0].strip()
        return MODULE_MAPPING.get(key, "misc")

    return "misc"


def parse_main_config():
    """Read the main config and return its lines."""
    if not CONFIG_FILE.exists():
        return []
    return CONFIG_FILE.read_text().splitlines()


def parse_modules():
    """
    Return (modules, main_lines) where modules is an OrderedDict of
    module_name -> list of raw lines, and main_lines is the list of raw lines
    in config.conf.
    """
    modules = OrderedDict()
    if CONF_D_DIR.exists():
        for path in sorted(CONF_D_DIR.glob("*.conf")):
            modules[path.stem] = path.read_text().splitlines()
    return modules, parse_main_config()


def parse_modules_as_dict():
    """
    Parse conf.d files into a dict of module -> {key: value|list(values)}.
    Directives like bind= become keys named 'bind' with list values.
    """
    result = OrderedDict()
    if not CONF_D_DIR.exists():
        return result

    for path in sorted(CONF_D_DIR.glob("*.conf")):
        module_name = path.stem
        grouped = defaultdict(list)
        for line in path.read_text().splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if "=" not in stripped:
                continue
            key, value = stripped.split("=", 1)
            grouped[key.strip()].append(value)

        module_dict = {}
        for key, values in grouped.items():
            module_dict[key] = values if len(values) > 1 else values[0]
        result[module_name] = module_dict

    return result


def sourced_modules_from_main(main_lines):
    """Return set of module names already referenced by source= lines."""
    sourced = set()
    for line in main_lines:
        stripped = line.strip()
        if stripped.startswith("source="):
            value = stripped.split("=", 1)[1].strip()
            path = Path(value)
            if not path.is_absolute():
                path = CONFIG_DIR / path
            sourced.add(path.stem)
    return sourced


def write_modules(modules, main_lines=None):
    """
    Write module files and ensure the main config contains source= lines for
    every module. Existing source=, blank, and comment lines in the main config
    are preserved.
    """
    CONF_D_DIR.mkdir(parents=True, exist_ok=True)

    for module_name, lines in modules.items():
        mod_path = CONF_D_DIR / f"{module_name}.conf"
        mod_path.write_text("\n".join(lines) + ("\n" if lines else ""))

    if main_lines is None:
        main_lines = parse_main_config()

    # Only source modules that have at least one real directive/option line.
    active_modules = []
    for module_name, lines in modules.items():
        for line in lines:
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                active_modules.append(module_name)
                break

    sourced = sourced_modules_from_main(main_lines)
    new_sources = []
    for module_name in active_modules:
        if module_name not in sourced:
            new_sources.append(f"source=conf.d/{module_name}.conf")

    if new_sources:
        # Preserve existing content, appending new source lines.
        out_lines = list(main_lines)
        if out_lines and out_lines[-1].strip() != "":
            out_lines.append("")
        out_lines.extend(new_sources)
        CONFIG_FILE.write_text("\n".join(out_lines) + "\n")


def find_key_location(modules, key):
    """Return (module_name, line_index) for an exact key= match, or (None, None)."""
    for module_name, lines in modules.items():
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if "=" not in stripped:
                continue
            line_key = stripped.split("=", 1)[0].strip()
            if line_key == key:
                return module_name, idx
    return None, None


def set_key(key, value, module=None):
    """
    Set a key=value option. If module is not specified, the key is updated in
    its existing location if present; otherwise it is placed according to the
    module mapping (defaulting to misc).
    """
    modules, main_lines = parse_modules()

    target_module = module
    if target_module is None:
        existing_module, _ = find_key_location(modules, key)
        target_module = existing_module or MODULE_MAPPING.get(key, "misc")

    if target_module not in modules:
        modules[target_module] = []

    lines = modules[target_module]
    updated = False
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            continue
        line_key = stripped.split("=", 1)[0].strip()
        if line_key == key:
            lines[idx] = f"{key}={value}"
            updated = True
            break

    if not updated:
        lines.append(f"{key}={value}")

    write_modules(modules, main_lines)
    return target_module


def find_mango_socket():
    """Locate the mmsg Unix socket, or None."""
    uid = os.getuid()
    run_dir = Path(f"/run/user/{uid}")
    sig = os.environ.get("MANGO_INSTANCE_SIGNATURE")

    if sig:
        # First treat it as a literal path.
        p = Path(sig)
        if p.exists() and p.is_socket():
            return str(p)
        # Then as an instance suffix.
        p = run_dir / f"mango-{sig}.sock"
        if p.exists():
            return str(p)

    if run_dir.exists():
        socks = sorted(run_dir.glob("mango-*.sock"))
        if socks:
            return str(socks[0])

    return None


def mmsg_dispatch(args_list):
    """Run mmsg dispatch with the given list of arguments."""
    sock = find_mango_socket()
    env = os.environ.copy()
    if sock:
        env["MANGO_INSTANCE_SIGNATURE"] = sock
    cmd = ["mmsg", "dispatch"]
    cmd.extend(args_list)

    try:
        result = subprocess.run(
            cmd, check=True, capture_output=True, text=True, env=env
        )
        output = (result.stdout or "").strip()
        if output.startswith('{"error"'):
            raise RuntimeError(f"mango rejected dispatch: {output}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"mmsg failed: {e.stderr or e.stdout or str(e)}")
    except FileNotFoundError:
        raise RuntimeError("mmsg not found in PATH")


def cmd_get(key):
    modules, _ = parse_modules()
    for lines in modules.values():
        for line in lines:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if "=" not in stripped:
                continue
            line_key, line_value = stripped.split("=", 1)
            if line_key.strip() == key:
                print(line_value)
                return
    print("")


def cmd_set(key, value, module=None):
    try:
        target = set_key(key, value, module)
        print(json.dumps({"ok": True, "module": target, "key": key, "value": value}))
    except Exception as e:
        error(str(e))


def cmd_get_module(module):
    data = parse_modules_as_dict()
    print(json.dumps(data.get(module, {}), indent=2))


def cmd_get_all():
    data = parse_modules_as_dict()
    print(json.dumps(data, indent=2))


def cmd_list_modules():
    modules, _ = parse_modules()
    print(json.dumps(list(modules.keys()), indent=2))


def cmd_set_many(json_str, reload_after=False, apply_after=False):
    """Set many key=value pairs at once. Input is a JSON object string."""
    try:
        pairs = json.loads(json_str)
        if not isinstance(pairs, dict):
            error("set-many expects a JSON object")
    except json.JSONDecodeError as e:
        error(f"Invalid JSON: {e}")

    modules_touched = set()
    try:
        for key, value in pairs.items():
            target = set_key(key, str(value))
            modules_touched.add(target)
        if apply_after:
            for key, value in pairs.items():
                mmsg_dispatch([f"setoption,{key},{value}"])
        elif reload_after:
            mmsg_dispatch(["reload_config"])
        print(
            json.dumps(
                {
                    "ok": True,
                    "modules": sorted(modules_touched),
                    "count": len(pairs),
                    "live": apply_after,
                    "reloaded": reload_after,
                },
                indent=2,
            )
        )
    except Exception as e:
        error(str(e))


def cmd_set_module(module, json_str, reload_after=False):
    """Set all keys in a single module from a JSON object string."""
    try:
        pairs = json.loads(json_str)
        if not isinstance(pairs, dict):
            error("set-module expects a JSON object")
    except json.JSONDecodeError as e:
        error(f"Invalid JSON: {e}")

    try:
        for key, value in pairs.items():
            set_key(key, str(value), module=module)
        if reload_after:
            mmsg_dispatch(["reload_config"])
        print(
            json.dumps(
                {"ok": True, "module": module, "count": len(pairs)}, indent=2
            )
        )
    except Exception as e:
        error(str(e))


def cmd_apply(key, value):
    try:
        mmsg_dispatch([f"setoption,{key},{value}"])
        print(json.dumps({"ok": True, "key": key, "value": value}))
    except Exception as e:
        error(str(e))


def cmd_set_apply(key, value):
    try:
        target = set_key(key, value)
        mmsg_dispatch([f"setoption,{key},{value}"])
        print(json.dumps({"ok": True, "module": target, "key": key, "value": value}))
    except Exception as e:
        error(str(e))


def cmd_reload():
    try:
        mmsg_dispatch(["reload_config"])
        print(json.dumps({"ok": True}))
    except Exception as e:
        error(str(e))


def cmd_list_directives(module):
    """
    List all directive lines in a module file.
    Returns JSON array of {index, prefix, value, raw} objects.
    """
    modules, _ = parse_modules()
    if module not in modules:
        print(json.dumps([]))
        return

    result = []
    dir_idx = 0
    for line in modules[module]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        matched = False
        for prefixes, _ in DIRECTIVE_MODULES:
            for prefix in sorted(prefixes, key=len, reverse=True):
                if stripped.startswith(prefix):
                    value = stripped[len(prefix):]
                    result.append({
                        "index": dir_idx,
                        "prefix": prefix.rstrip("="),
                        "value": value,
                        "raw": line
                    })
                    dir_idx += 1
                    matched = True
                    break
            if matched:
                break
        if not matched and "=" in stripped:
            key = stripped.split("=", 1)[0].strip()
            result.append({
                "index": dir_idx,
                "prefix": key,
                "value": stripped.split("=", 1)[1],
                "raw": line
            })
            dir_idx += 1

    print(json.dumps(result, indent=2))


def cmd_add_directive(module, prefix, value):
    """Add a directive line to a module file and reload config."""
    modules, main_lines = parse_modules()
    if module not in modules:
        modules[module] = []
    modules[module].append(f"{prefix}={value}")
    write_modules(modules, main_lines)
    mmsg_dispatch(["reload_config"])
    print(json.dumps({"ok": True, "module": module, "prefix": prefix, "value": value}))


def cmd_remove_directive(module, index):
    """Remove a directive line from a module file by its directive index (0-based)."""
    modules, main_lines = parse_modules()
    if module not in modules:
        error(f"Module '{module}' not found")

    lines = modules[module]
    dir_idx = 0
    remove_line_idx = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if dir_idx == index:
            remove_line_idx = i
            break
        dir_idx += 1

    if remove_line_idx is None:
        error(f"Directive index {index} not found in module '{module}'")

    removed = lines.pop(remove_line_idx)
    write_modules(modules, main_lines)
    mmsg_dispatch(["reload_config"])
    print(json.dumps({"ok": True, "module": module, "removed": removed.strip()}))


def cmd_validate():
    try:
        result = subprocess.run(
            ["mango", "-p"],
            cwd=str(CONFIG_DIR),
            capture_output=True,
            text=True,
        )
        ok = result.returncode == 0
        output = {
            "ok": ok,
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
        print(json.dumps(output, indent=2))
        return ok
    except FileNotFoundError:
        output = {
            "ok": False,
            "returncode": -1,
            "stdout": "",
            "stderr": "mango binary not found in PATH",
        }
        print(json.dumps(output, indent=2))
        return False
    except Exception as e:
        output = {
            "ok": False,
            "returncode": -1,
            "stdout": "",
            "stderr": str(e),
        }
        print(json.dumps(output, indent=2))
        return False


def cmd_migrate():
    if not CONFIG_FILE.exists():
        error("config.conf not found")

    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    backup = CONFIG_DIR / f"config.conf.bak-{timestamp}"
    shutil.copy2(CONFIG_FILE, backup)

    try:
        lines = CONFIG_FILE.read_text().splitlines()

        # First pass: classify real directives/options.
        line_modules = [classify_line(line) for line in lines]

        # Second pass: attach comments/blanks to the nearest following real line,
        # falling back to the nearest preceding real line, then misc.
        for i in range(len(line_modules)):
            if line_modules[i] is not None:
                continue
            target = None
            for j in range(i + 1, len(line_modules)):
                if line_modules[j] is not None:
                    target = line_modules[j]
                    break
            if target is None:
                for j in range(i - 1, -1, -1):
                    if line_modules[j] is not None:
                        target = line_modules[j]
                        break
            line_modules[i] = target or "misc"

        # Group lines into modules.
        raw_modules = OrderedDict()
        for mod, line in zip(line_modules, lines):
            raw_modules.setdefault(mod, []).append(line)

        # Apply preferred module order.
        modules = OrderedDict()
        for mod in MODULE_ORDER:
            if mod in raw_modules:
                modules[mod] = raw_modules[mod]
        for mod, mod_lines in raw_modules.items():
            if mod not in modules:
                modules[mod] = mod_lines

        # Ensure output directory exists.
        CONF_D_DIR.mkdir(parents=True, exist_ok=True)

        # Write module files.
        for mod, mod_lines in modules.items():
            (CONF_D_DIR / f"{mod}.conf").write_text(
                "\n".join(mod_lines) + ("\n" if mod_lines else "")
            )

        # Replace main config with source= directives only.
        main_lines = [f"source=conf.d/{mod}.conf" for mod in modules.keys()]
        CONFIG_FILE.write_text("\n".join(main_lines) + "\n")

        # Validate.
        if not cmd_validate():
            # Restore backup on failure.
            shutil.copy2(backup, CONFIG_FILE)
            error(
                f"Validation failed after migration; restored config.conf from {backup}"
            )

        print(
            json.dumps(
                {
                    "ok": True,
                    "backup": str(backup),
                    "modules": list(modules.keys()),
                },
                indent=2,
            )
        )
    except Exception as e:
        # Attempt to restore on any unexpected error.
        if backup.exists() and CONFIG_FILE.exists():
            shutil.copy2(backup, CONFIG_FILE)
        error(f"Migration failed: {e}")


def main():
    args = sys.argv[1:]
    if not args:
        error("No subcommand provided")

    cmd = args[0]

    def has_flag(flag):
        return flag in args

    def consume_flag(flag):
        if flag in args:
            args.remove(flag)
            return True
        return False

    if cmd == "get" and len(args) == 2:
        cmd_get(args[1])
    elif cmd == "set":
        reload_after = consume_flag("--reload")
        if len(args) < 3:
            error("Usage: set <key> <value> [--module <module>] [--reload]")
        key = args[1]
        value = args[2]
        module = None
        if "--module" in args:
            idx = args.index("--module")
            if idx + 1 >= len(args):
                error("--module requires a value")
            module = args[idx + 1]
        try:
            target = set_key(key, value, module)
            if reload_after:
                mmsg_dispatch(["reload_config"])
            print(
                json.dumps(
                    {"ok": True, "module": target, "key": key, "value": value}
                )
            )
        except Exception as e:
            error(str(e))
    elif cmd == "get-module" and len(args) == 2:
        cmd_get_module(args[1])
    elif cmd == "get-all" and len(args) == 1:
        cmd_get_all()
    elif cmd == "list-modules" and len(args) == 1:
        cmd_list_modules()
    elif cmd == "apply" and len(args) == 3:
        cmd_apply(args[1], args[2])
    elif cmd == "set-apply" and len(args) == 3:
        cmd_set_apply(args[1], args[2])
    elif cmd == "set-many":
        reload_after = consume_flag("--reload")
        apply_after = consume_flag("--apply")
        if len(args) != 2:
            error("Usage: set-many '<json>' [--reload|--apply]")
        cmd_set_many(args[1], reload_after, apply_after)
    elif cmd == "set-module":
        reload_after = consume_flag("--reload")
        if len(args) != 3:
            error("Usage: set-module <module> '<json>' [--reload]")
        cmd_set_module(args[1], args[2], reload_after)
    elif cmd == "reload" and len(args) == 1:
        cmd_reload()
    elif cmd == "list-directives" and len(args) == 2:
        cmd_list_directives(args[1])
    elif cmd == "add-directive" and len(args) == 4:
        cmd_add_directive(args[1], args[2], args[3])
    elif cmd == "remove-directive" and len(args) == 3:
        cmd_remove_directive(args[1], int(args[2]))
    elif cmd == "validate" and len(args) == 1:
        cmd_validate()
    elif cmd == "migrate" and len(args) == 1:
        cmd_migrate()
    else:
        error(f"Unknown or invalid usage for subcommand: {cmd}")


if __name__ == "__main__":
    main()
