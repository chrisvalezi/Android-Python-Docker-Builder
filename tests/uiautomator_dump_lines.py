import pathlib
import subprocess
import sys
import xml.etree.ElementTree as ET


LOCAL_DUMP_PATH = pathlib.Path("/data/local/tmp/window_dump.xml")
SDCARD_DUMP_PATH = pathlib.Path("/sdcard/window_dump.xml")


def shell(args, check=True):
    return subprocess.run(
        args,
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )


def short(value, limit=80):
    value = (value or "").replace("\n", " ").strip()
    if len(value) <= limit:
        return value
    return value[: limit - 1] + "."


def main():
    dump_path = dump_ui_xml()
    tree = ET.parse(dump_path)
    root = tree.getroot()
    nodes = list(root.iter("node"))

    print(f"nodes: {len(nodes)}", file=sys.stderr)
    for index, node in enumerate(nodes, 1):
        attrs = node.attrib
        parts = [
            f"{index:04d}",
            f"text={short(attrs.get('text'))!r}",
            f"desc={short(attrs.get('content-desc'))!r}",
            f"res={attrs.get('resource-id', '')!r}",
            f"class={attrs.get('class', '')!r}",
            f"pkg={attrs.get('package', '')!r}",
            f"bounds={attrs.get('bounds', '')!r}",
            f"clickable={attrs.get('clickable', '')}",
            f"enabled={attrs.get('enabled', '')}",
        ]
        print(" | ".join(parts))


def dump_ui_xml():
    for path in (LOCAL_DUMP_PATH, SDCARD_DUMP_PATH):
        path.unlink(missing_ok=True)
        result = shell(["uiautomator", "dump", str(path)], check=False)
        print(f"dump command: uiautomator dump {path}", file=sys.stderr)
        print(f"dump exit: {result.returncode}", file=sys.stderr)
        if result.stdout.strip():
            print(f"dump output: {result.stdout.strip()}", file=sys.stderr)

        if path.exists() and path.stat().st_size > 0:
            if path != LOCAL_DUMP_PATH:
                LOCAL_DUMP_PATH.unlink(missing_ok=True)
                copy = shell(["cp", str(path), str(LOCAL_DUMP_PATH)], check=False)
                if copy.returncode == 0 and LOCAL_DUMP_PATH.exists():
                    return LOCAL_DUMP_PATH
            return path

    diagnostic = shell(
        [
            "sh",
            "-lc",
            "command -v uiautomator; ls -l /data/local/tmp/window_dump.xml /sdcard/window_dump.xml 2>&1; dumpsys window displays 2>/dev/null | head -40",
        ],
        check=False,
    )
    raise SystemExit(f"uiautomator did not create an XML dump\n{diagnostic.stdout.strip()}")


if __name__ == "__main__":
    main()
