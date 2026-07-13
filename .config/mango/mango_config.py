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
import tempfile
import time
import uuid
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
MONITOR_PREVIEW_DIR = Path.home() / ".cache" / "qs" / "monitor-preview"

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


def atomic_write_text(path, content):
    """Atomically replace a text file while preserving its existing mode."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    fd, temp_name = tempfile.mkstemp(
        dir=str(path.parent), prefix=f".{path.name}.", suffix=".tmp"
    )
    temp_path = Path(temp_name)

    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, mode)
        os.replace(temp_path, path)
    finally:
        if temp_path.exists():
            temp_path.unlink()


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
        atomic_write_text(mod_path, "\n".join(lines) + ("\n" if lines else ""))

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
            new_sources.append(f"source=./conf.d/{module_name}.conf")

    if new_sources:
        # Preserve existing content, appending new source lines.
        out_lines = list(main_lines)
        if out_lines and out_lines[-1].strip() != "":
            out_lines.append("")
        out_lines.extend(new_sources)
        atomic_write_text(CONFIG_FILE, "\n".join(out_lines) + "\n")


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


def set_key_in_modules(modules, key, value, module=None):
    """Update a key in an already-loaded module mapping without writing it."""
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

    return target_module


def set_key(key, value, module=None):
    """
    Set a key=value option. If module is not specified, the key is updated in
    its existing location if present; otherwise it is placed according to the
    module mapping (defaulting to misc).
    """
    modules, main_lines = parse_modules()
    target_module = set_key_in_modules(modules, key, value, module)
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


def validate_config():
    """Raise when Mango rejects the persisted configuration."""
    try:
        result = subprocess.run(
            ["mango", "-p"],
            cwd=str(CONFIG_DIR),
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("mango binary not found in PATH") from exc

    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "configuration validation failed").strip()
        raise RuntimeError(detail)


def restore_file(path, previous_content):
    """Restore a file snapshot, removing files that did not previously exist."""
    if previous_content is None:
        path.unlink(missing_ok=True)
    else:
        atomic_write_text(path, previous_content)


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


def parse_monitor_value(value):
    result = {}
    for part in str(value).split(","):
        if ":" not in part:
            continue
        key, raw = part.split(":", 1)
        result[key.strip()] = raw.strip()
    return result


def persisted_monitor_rules():
    data = parse_modules_as_dict().get("monitors", {})
    values = data.get("monitorrule", [])
    if isinstance(values, str):
        values = [values]
    return [parse_monitor_value(value) for value in values]


def exact_monitor_name(value):
    value = str(value or "")
    if value.startswith("^") and value.endswith("$"):
        return value[1:-1]
    return value


def merge_monitor_sources(wlr_outputs, mango_payload):
    mango_by_name = {
        item.get("name"): item for item in mango_payload.get("monitors", [])
    }
    rules = persisted_monitor_rules()
    result = []
    transform_to_rr = {
        "normal": 0, "90": 1, "180": 2, "270": 3,
        "flipped": 4, "flipped-90": 5, "flipped-180": 6, "flipped-270": 7,
    }
    for output in wlr_outputs:
        name = output.get("name", "")
        live = mango_by_name.get(name, {})
        current = next((mode for mode in output.get("modes", []) if mode.get("current")), {})
        rule = next((item for item in rules if exact_monitor_name(item.get("name")) == name), {})
        position = output.get("position") or {}
        item = {
            "name": name,
            "description": output.get("description") or name,
            "make": output.get("make", ""),
            "model": output.get("model", ""),
            "serial": output.get("serial", ""),
            "enabled": bool(output.get("enabled", True)),
            "active": bool(live.get("active", output.get("enabled", True))),
            "x": int(live.get("x", position.get("x", rule.get("x", 0)))),
            "y": int(live.get("y", position.get("y", rule.get("y", 0)))),
            # mmsg exposes logical dimensions after scaling (for example,
            # 1536x864 at 125% for a physical 1920x1080 mode). Mode selection
            # must always use the physical wlr-randr dimensions.
            "width": int(current.get("width", rule.get("width", live.get("width", 0)))),
            "height": int(current.get("height", rule.get("height", live.get("height", 0)))),
            "refresh": float(current.get("refresh", rule.get("refresh", 60))),
            "scale": float(live.get("scale", output.get("scale", rule.get("scale", 1)))),
            "rr": int(rule.get("rr", transform_to_rr.get(output.get("transform", "normal"), 0))),
            "vrr": int(rule.get("vrr", 1 if output.get("adaptive_sync") else 0)),
            "custom": int(rule.get("custom", 0)),
            "configured": bool(rule),
            "modes": output.get("modes", []),
        }
        result.append(item)
    return result


def run_json_command(command):
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(result.stdout or "{}")


def probe_monitors():
    try:
        wlr = run_json_command(["wlr-randr", "--json"])
    except (FileNotFoundError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"could not query outputs with wlr-randr: {exc}") from exc
    try:
        mango = run_json_command(["mmsg", "get", "all-monitors"])
    except (FileNotFoundError, subprocess.CalledProcessError, json.JSONDecodeError):
        mango = {"monitors": []}
    return merge_monitor_sources(wlr, mango)


def cmd_probe_monitors():
    try:
        print(json.dumps({"ok": True, "monitors": probe_monitors()}))
    except Exception as exc:
        error(str(exc))


def normalize_monitor_layout(monitors):
    normalized = [dict(item) for item in monitors]
    if not normalized:
        return normalized
    min_x = min(int(item.get("x", 0)) for item in normalized)
    min_y = min(int(item.get("y", 0)) for item in normalized)
    for item in normalized:
        item["x"] = int(item.get("x", 0)) - min_x
        item["y"] = int(item.get("y", 0)) - min_y
    return normalized


def wlr_command_for(monitor):
    transforms = ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]
    rr = int(monitor.get("rr", 0))
    transform = transforms[rr] if 0 <= rr < len(transforms) else "normal"
    mode = f"{int(monitor['width'])}x{int(monitor['height'])}@{float(monitor['refresh']):g}Hz"
    command = ["wlr-randr", "--output", str(monitor["name"])]
    command.extend(["--custom-mode" if int(monitor.get("custom", 0)) else "--mode", mode])
    command.extend(["--pos", f"{int(monitor.get('x', 0))},{int(monitor.get('y', 0))}"])
    command.extend(["--scale", f"{float(monitor.get('scale', 1)):g}"])
    command.extend(["--transform", transform])
    command.extend(["--adaptive-sync", "enabled" if int(monitor.get("vrr", 0)) else "disabled"])
    return command


def validate_monitor_configs(monitors):
    if not isinstance(monitors, list) or not monitors:
        raise ValueError("at least one monitor is required")
    seen = set()
    for item in monitors:
        name = str(item.get("name", "")).strip()
        if not name or name in seen:
            raise ValueError("monitor names must be present and unique")
        seen.add(name)
        if int(item.get("width", 0)) <= 0 or int(item.get("height", 0)) <= 0:
            raise ValueError(f"invalid resolution for {name}")
        if float(item.get("refresh", 0)) <= 0 or not 0.01 <= float(item.get("scale", 0)) <= 100:
            raise ValueError(f"invalid refresh or scale for {name}")
        if int(item.get("x", -1)) < 0 or int(item.get("y", -1)) < 0:
            raise ValueError("monitor coordinates must be non-negative")
        if not 0 <= int(item.get("rr", 0)) <= 7:
            raise ValueError(f"invalid transform for {name}")


def apply_monitor_configs(monitors):
    for monitor in monitors:
        command = wlr_command_for(monitor)
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or exc.stdout or str(exc)).strip()
            raise RuntimeError(f"{monitor['name']}: {detail}") from exc


def monitor_rule_value(item):
    matcher = f"name:^{item['name']}$"
    if item.get("match_by_identity"):
        matcher = ",".join(
            f"{key}:{item[key]}" for key in ("make", "model", "serial") if item.get(key)
        ) or matcher
    return matcher + "," + ",".join([
        f"width:{int(item['width'])}", f"height:{int(item['height'])}",
        f"refresh:{float(item['refresh']):g}", f"x:{int(item['x'])}", f"y:{int(item['y'])}",
        f"scale:{float(item.get('scale', 1)):g}", f"vrr:{int(item.get('vrr', 0))}",
        f"rr:{int(item.get('rr', 0))}", f"custom:{int(item.get('custom', 0))}",
    ])


def preview_state_path(token):
    return MONITOR_PREVIEW_DIR / f"{token}.json"


def cmd_preview_monitors(json_str):
    try:
        proposed = normalize_monitor_layout(json.loads(json_str))
        validate_monitor_configs(proposed)
        previous = probe_monitors()
        token = uuid.uuid4().hex
        MONITOR_PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
        atomic_write_text(preview_state_path(token), json.dumps({"previous": previous, "proposed": proposed}))
        try:
            apply_monitor_configs(proposed)
        except Exception as apply_error:
            try:
                apply_monitor_configs(previous)
            except Exception:
                pass
            finally:
                preview_state_path(token).unlink(missing_ok=True)
            raise apply_error
        subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve()), "monitor-preview-watch", token],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
        print(json.dumps({"ok": True, "token": token, "timeout": 20, "monitors": proposed}))
    except Exception as exc:
        error(str(exc))


def cmd_revert_monitor_preview(token):
    path = preview_state_path(token)
    try:
        state = json.loads(path.read_text())
        apply_monitor_configs(state["previous"])
        path.unlink(missing_ok=True)
        print(json.dumps({"ok": True, "reverted": True}))
    except Exception as exc:
        error(str(exc))


def cmd_confirm_monitor_preview(token):
    path = preview_state_path(token)
    try:
        state = json.loads(path.read_text())
        proposed = state["proposed"]
        validate_monitor_configs(proposed)
        module_path = CONF_D_DIR / "monitors.conf"
        previous = module_path.read_text() if module_path.exists() else None
        preserved = [] if previous is None else [
            line for line in previous.splitlines() if not line.strip().startswith("monitorrule=")
        ]
        lines = preserved + [f"monitorrule={monitor_rule_value(item)}" for item in proposed]
        try:
            atomic_write_text(module_path, "\n".join(lines).rstrip() + "\n")
            validate_config()
            mmsg_dispatch(["reload_config"])
        except Exception:
            restore_file(module_path, previous)
            mmsg_dispatch(["reload_config"])
            raise
        path.unlink(missing_ok=True)
        print(json.dumps({"ok": True, "persisted": True}))
    except Exception as exc:
        error(str(exc))


def cmd_monitor_preview_watch(token):
    time.sleep(20)
    path = preview_state_path(token)
    if not path.exists():
        return
    try:
        state = json.loads(path.read_text())
        apply_monitor_configs(state["previous"])
    finally:
        path.unlink(missing_ok=True)


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
        modules, main_lines = parse_modules()
        for key, value in pairs.items():
            target = set_key_in_modules(modules, key, str(value))
            modules_touched.add(target)
        write_modules(modules, main_lines)
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
        modules, main_lines = parse_modules()
        for key, value in pairs.items():
            set_key_in_modules(modules, key, str(value), module=module)
        write_modules(modules, main_lines)
        if reload_after:
            mmsg_dispatch(["reload_config"])
        print(
            json.dumps(
                {"ok": True, "module": module, "count": len(pairs)}, indent=2
            )
        )
    except Exception as e:
        error(str(e))


def cmd_apply_style(json_str):
    """Atomically persist a cross-module visual style and reload MangoWM."""
    try:
        pairs = json.loads(json_str)
        if not isinstance(pairs, dict) or not pairs:
            error("apply-style expects a non-empty JSON object")
    except json.JSONDecodeError as e:
        error(f"Invalid JSON: {e}")

    modules, main_lines = parse_modules()
    touched = set()
    for key, value in pairs.items():
        touched.add(set_key_in_modules(modules, key, str(value)))

    snapshots = {}
    for module in touched:
        path = CONF_D_DIR / f"{module}.conf"
        snapshots[path] = path.read_text() if path.exists() else None
    previous_main = CONFIG_FILE.read_text() if CONFIG_FILE.exists() else None

    try:
        write_modules(modules, main_lines)
        validate_config()
        mmsg_dispatch(["reload_config"])
        print(json.dumps({
            "ok": True,
            "modules": sorted(touched),
            "count": len(pairs),
            "persisted": True,
            "reloaded": True,
        }))
    except Exception as e:
        for path, previous in snapshots.items():
            restore_file(path, previous)
        restore_file(CONFIG_FILE, previous_main)
        try:
            mmsg_dispatch(["reload_config"])
        except Exception:
            pass
        error(str(e))


def cmd_apply(key, value):
    try:
        mmsg_dispatch([f"setoption,{key},{value}"])
        print(json.dumps({"ok": True, "key": key, "value": value}))
    except Exception as e:
        error(str(e))


def cmd_set_apply(key, value):
    modules, main_lines = parse_modules()
    existing_module, _ = find_key_location(modules, key)
    target = existing_module or MODULE_MAPPING.get(key, "misc")
    module_path = CONF_D_DIR / f"{target}.conf"
    previous_module = module_path.read_text() if module_path.exists() else None
    previous_main = CONFIG_FILE.read_text() if CONFIG_FILE.exists() else None

    try:
        set_key_in_modules(modules, key, value, module=target)
        write_modules(modules, main_lines)
        validate_config()
        mmsg_dispatch(["reload_config"])
        print(
            json.dumps(
                {
                    "ok": True,
                    "module": target,
                    "key": key,
                    "value": value,
                    "persisted": True,
                    "reloaded": True,
                }
            )
        )
    except Exception as e:
        restore_file(module_path, previous_module)
        restore_file(CONFIG_FILE, previous_main)
        try:
            mmsg_dispatch(["reload_config"])
        except Exception:
            pass
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
    """Add a directive, validate it, reload MangoWM, and roll back on failure."""
    modules, main_lines = parse_modules()
    module_path = CONF_D_DIR / f"{module}.conf"
    previous_module = module_path.read_text() if module_path.exists() else None
    previous_main = CONFIG_FILE.read_text() if CONFIG_FILE.exists() else None
    if module not in modules:
        modules[module] = []
    modules[module].append(f"{prefix}={value}")
    try:
        write_modules(modules, main_lines)
        validate_config()
        mmsg_dispatch(["reload_config"])
        print(json.dumps({"ok": True, "module": module, "prefix": prefix, "value": value}))
    except Exception as exc:
        restore_file(module_path, previous_module)
        restore_file(CONFIG_FILE, previous_main)
        try:
            mmsg_dispatch(["reload_config"])
        except Exception:
            pass
        error(str(exc))


def cmd_remove_directive(module, index):
    """Remove a directive by index, validating and rolling back on failure."""
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

    module_path = CONF_D_DIR / f"{module}.conf"
    previous_module = module_path.read_text() if module_path.exists() else None
    previous_main = CONFIG_FILE.read_text() if CONFIG_FILE.exists() else None
    removed = lines.pop(remove_line_idx)
    try:
        write_modules(modules, main_lines)
        validate_config()
        mmsg_dispatch(["reload_config"])
        print(json.dumps({"ok": True, "module": module, "removed": removed.strip()}))
    except Exception as exc:
        restore_file(module_path, previous_module)
        restore_file(CONFIG_FILE, previous_main)
        try:
            mmsg_dispatch(["reload_config"])
        except Exception:
            pass
        error(str(exc))


def cmd_validate():
    try:
        validate_config()
        print(json.dumps({"ok": True}, indent=2))
        return True
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}, indent=2))
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
            atomic_write_text(
                CONF_D_DIR / f"{mod}.conf",
                "\n".join(mod_lines) + ("\n" if mod_lines else ""),
            )

        # Replace main config with source= directives only.
        main_lines = [f"source=./conf.d/{mod}.conf" for mod in modules.keys()]
        atomic_write_text(CONFIG_FILE, "\n".join(main_lines) + "\n")

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
    elif cmd == "apply-style" and len(args) == 2:
        cmd_apply_style(args[1])
    elif cmd == "probe-monitors" and len(args) == 1:
        cmd_probe_monitors()
    elif cmd == "preview-monitors" and len(args) == 2:
        cmd_preview_monitors(args[1])
    elif cmd == "confirm-monitor-preview" and len(args) == 2:
        cmd_confirm_monitor_preview(args[1])
    elif cmd == "revert-monitor-preview" and len(args) == 2:
        cmd_revert_monitor_preview(args[1])
    elif cmd == "monitor-preview-watch" and len(args) == 2:
        cmd_monitor_preview_watch(args[1])
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
