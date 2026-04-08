import ctypes
import json
import os
import pathlib
import re
import secrets
import sqlite3
import ssl
import string
import subprocess
import sys
import tempfile
import time
from base64 import b64encode
from collections import Counter, defaultdict
from csv import DictReader
from datetime import datetime
from hashlib import sha256
from http.server import BaseHTTPRequestHandler
from itertools import islice
from random import Random
from urllib.request import Request

import jinja2
import requests
from faker import Faker

print("hello from android")
print("python:", sys.version)
print("executable:", sys.executable)
print("prefix:", sys.prefix)
print("sys.path:")
for entry in sys.path:
    print(" -", entry)

payload = {"abi": "x86_64", "ssl": ssl.OPENSSL_VERSION}
print("json:", json.dumps(payload, sort_keys=True))

with tempfile.NamedTemporaryFile("w+", delete=False) as handle:
    handle.write("ok\n")
    temp_path = pathlib.Path(handle.name)

print("tempfile:", temp_path)
print("tempfile exists:", temp_path.exists())

db = sqlite3.connect(":memory:")
db.execute("create table t (id integer primary key, value text)")
db.execute("insert into t(value) values (?)", ("android",))
row = db.execute("select value from t").fetchone()
print("sqlite3:", row[0])

libc = ctypes.CDLL(None)
print("ctypes libc:", bool(libc))

rand = Random(42)
print("random/string:", "".join(rand.choice(string.ascii_lowercase) for _ in range(8)))
print("secrets:", len(secrets.token_hex(8)))
print("regex:", bool(re.search(r"android", "hello android shell")))
print("base64:", b64encode(b"android").decode("ascii"))
print("hashlib:", sha256(b"android").hexdigest()[:16])
print("datetime:", datetime.utcnow().strftime("%Y-%m-%d"))
print("time:", int(time.time()) > 0)
print("collections:", Counter("android")["a"], defaultdict(int)["missing"])
print("itertools:", list(islice(range(10), 3)))
print("csv:", list(DictReader(["name,value", "android,1"]))[0]["name"])
print("urllib.request:", Request("https://example.com").method)
print("http.server:", BaseHTTPRequestHandler.server_version)
print(
    "subprocess:",
    subprocess.check_output(
        ["/system/bin/sh", "-lc", "printf subprocess-ok"],
        text=True,
    ).strip(),
)

fake = Faker()
fake.seed_instance(42)
template = jinja2.Template("{{ greeting }} {{ target }}")
rendered = template.render(greeting="hello", target="android")
resp = requests.models.Response()
resp.status_code = 204
print("faker:", fake.name())
print("jinja2:", rendered)
print("requests:", resp.status_code)

print("cwd:", os.getcwd())
