import ctypes
import json
import os
import pathlib
import sqlite3
import ssl
import subprocess
import sys
import tempfile
from datetime import UTC, datetime
from hashlib import sha256
from urllib.request import urlopen

import numpy
import pandas


def check(name, fn):
    try:
        result = fn()
    except Exception as exc:
        print(f"[FAIL] {name}: {type(exc).__name__}: {exc}")
        raise
    print(f"[OK] {name}: {result}")


def main():
    base = pathlib.Path("/data/local/tmp")
    if not base.is_dir():
        raise SystemExit("/data/local/tmp does not exist")

    print("python:", sys.version)
    print("executable:", sys.executable)
    print("prefix:", sys.prefix)
    print("cwd:", os.getcwd())
    print("time_utc:", datetime.now(UTC).isoformat())

    check("path writable", lambda: base.joinpath("python-validation-write.txt").write_text("ok\n"))
    check("tempfile", lambda: pathlib.Path(tempfile.NamedTemporaryFile(dir=base, delete=False).name).exists())
    check("json", lambda: json.dumps({"android": True, "abi": "x86_64"}, sort_keys=True))
    check("hashlib", lambda: sha256(b"android-python").hexdigest()[:16])
    check("sqlite3", sqlite_check)
    check("ctypes libc", lambda: bool(ctypes.CDLL(None)))
    check("subprocess", lambda: subprocess.check_output(["/system/bin/sh", "-lc", "printf ok"], text=True))
    check("ssl", lambda: ssl.OPENSSL_VERSION)
    check("numpy", lambda: f"{numpy.__version__} sum={numpy.array([1, 2, 3]).sum()}")
    check("pandas", lambda: f"{pandas.__version__} sum={pandas.DataFrame({'value': [1, 2, 3]})['value'].sum()}")
    check("https", https_check)

    print("validation: ok")


def sqlite_check():
    db = sqlite3.connect(":memory:")
    db.execute("create table t (value text)")
    db.execute("insert into t(value) values (?)", ("ok",))
    return db.execute("select value from t").fetchone()[0]


def https_check():
    with urlopen("https://example.com", timeout=15) as response:
        return f"status={response.status} bytes={len(response.read(80))}"


if __name__ == "__main__":
    main()
