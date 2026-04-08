import pathlib
import sys


def main() -> None:
    marker = pathlib.Path("/data/local/tmp/android-python-external.txt")
    marker.write_text("external script ok\n", encoding="utf-8")
    print("external script:", marker)
    print("argv0:", sys.argv[0])


if __name__ == "__main__":
    main()
