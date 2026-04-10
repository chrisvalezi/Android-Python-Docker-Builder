# Android Python Docker Builder

[English documentation](./README.en.md)

Projeto reprodutível para compilar e empacotar `CPython` para rodar no shell puro do Android, com foco em `Android x86_64` dentro de `Redroid`, sem `Termux`, sem `APK` e sem `Gradle`.

## Objetivo

Este repositório entrega:

- build reproduzível via Docker;
- cross-compile com Android NDK;
- runtime portátil para shell puro do Android;
- variantes `full`, `minimal` e `slim`;
- wrappers globais em `/system/bin/python3`, `/system/bin/python` e `/system/bin/pip`;
- testes automatizados no Redroid;
- suporte prático a `pip` para pacotes pure-Python.

Pacotes adicionais já embutidos no runtime:

- `faker`
- `requests`
- `jinja2`
- `numpy`
- `pandas`
- `Pillow`
- `lxml`
- `uiautomator2`

## Decisões técnicas

- `CPython 3.12.12`
- `Android NDK r27d`
- `API 24`
- alvo principal: `x86_64`
- pronto para expansão para `arm64-v8a`, `armeabi-v7a` e `x86`

O launcher em shell configura:

- `PYTHONHOME`
- `PYTHONPATH`
- `LD_LIBRARY_PATH`
- `LD_PRELOAD`
- `TMPDIR`
- `LANG`
- `LC_ALL`
- `SSL_CERT_FILE`

Isso foi necessário para o runtime funcionar de forma confiável no linker do Android.

## Estrutura

```text
.
├── .github/workflows/
├── Dockerfile
├── Makefile
├── README.md
├── config/build.env
├── docker-compose.yml
├── output/
├── patches/
├── scripts/
│   ├── build-all.sh
│   ├── build-cpython.sh
│   ├── build-deps.sh
│   ├── build-host-python.sh
│   ├── build-matrix.sh
│   ├── clean.sh
│   ├── export-artifacts.sh
│   ├── package-runtime.sh
│   ├── redroid-enable-pip.sh
│   ├── redroid-pip-install.sh
│   ├── redroid-push.sh
│   ├── redroid-shell.sh
│   ├── redroid-test.sh
│   └── lib/common.sh
└── tests/
    ├── android_smoke_test.py
    ├── external_hello.py
    └── network_tls_test.py
```

## Requisitos

No host:

- Docker
- Docker Compose v2
- um Redroid já rodando, por exemplo com container `android-15`

No Android Redroid:

- shell via `docker exec`
- diretório gravável em `/data/local/tmp`
- rede funcional se quiser rodar os testes de TLS/HTTPS

## Como compilar

### 1. Construir a imagem do builder

```bash
docker compose build builder
```

### 2. Subir o container builder

```bash
docker compose up -d builder
```

### 3. Executar o build completo

```bash
docker compose exec builder bash -lc "./scripts/build-all.sh"
```

Atalho com `make`:

```bash
make compose-build
make compose-up
make build
```

O build completo também compila as wheels Android nativas de `numpy`, `pandas`, `Pillow`, `lxml` e `uiautomator2` antes de instalar os pacotes no runtime.

## Como compilar para outra ABI

Exemplo para `arm64-v8a`:

```bash
docker compose exec builder bash -lc "ANDROID_ABI=arm64-v8a ./scripts/build-all.sh"
```

Atalho equivalente:

```bash
ANDROID_ABI=arm64-v8a make build
```

Build serial para várias ABIs:

```bash
docker compose exec builder bash -lc "./scripts/build-matrix.sh"
```

## Artefatos gerados

Depois do build, você terá algo como:

- `output/dist/python-android-x86_64-full.tar.gz`
- `output/dist/python-android-x86_64-minimal.tar.gz`
- `output/dist/python-android-x86_64-slim.tar.gz`
- `output/dist/python-android-arm64-v8a-full.tar.gz`
- `output/dist/python-android-arm64-v8a-minimal.tar.gz`
- `output/dist/python-android-arm64-v8a-slim.tar.gz`
- `output/dist/SHA256SUMS`
- `output/dist/ARTIFACTS.txt`

Observação: o projeto usa `output/` como diretório oficial de saída. Não existe uma pasta `out/` neste repositório.

As wheels nativas de `numpy`, `pandas`, `Pillow`, `lxml` e `uiautomator2` ficam em:

- `output/wheelhouse/x86_64/`
- `output/wheelhouse/arm64-v8a/`

## Variantes

- `full`: stdlib expandida, `ensurepip`, `venv`, headers e arquivos auxiliares.
- `minimal`: stdlib majoritariamente zipada, mantém `lib-dynload`, `site-packages`, `ensurepip` e `venv`.
- `slim`: runtime menor, sem headers, sem manpages, sem pkgconfig, sem testes e sem bins auxiliares.

## Como instalar no Android

### Método recomendado: deploy automático no Redroid

```bash
./scripts/redroid-push.sh
```

Por padrão, isso:

1. copia a variante `minimal` para:

```text
/data/local/tmp/<abi>/python-android-<abi>
```

2. cria wrappers globais em:

- `/system/bin/python3`
- `/system/bin/python`
- `/system/bin/pip`

Atalho com `make`:

```bash
make redroid-push
```

Para instalar no Redroid `x86_64`:

```bash
REDROID_CONTAINER=android-15 ANDROID_ABI=x86_64 ./scripts/redroid-push.sh
```

Para instalar no Redroid `arm64-v8a`:

```bash
REDROID_CONTAINER=android-15 ANDROID_ABI=arm64-v8a ./scripts/redroid-push.sh
```

O deploy usa o tarball correto de `output/dist/python-android-<abi>-<variant>.tar.gz`, então ele não depende do último ABI empacotado em `output/runtime/`.

Depois do deploy:

```bash
docker exec android-15 sh -lc 'python3 --version'
docker exec android-15 sh -lc 'python -c "import sys; print(sys.version)"'
docker exec android-15 sh -lc 'python3 -c "import numpy, pandas, uiautomator2; from PIL import Image; from lxml import etree; print(numpy.__version__, pandas.__version__, Image.__version__)"'
```

Habilitar e testar `pip` no Redroid:

```bash
REDROID_CONTAINER=android-15 ./scripts/redroid-enable-pip.sh
docker exec android-15 sh -lc 'pip --version'
docker exec android-15 sh -lc 'pip install urllib3'
```

Observação para `arm64-v8a`: o container Android precisa executar binários ARM64 nativos. Alguns Redroid `x86_64` anunciam `arm64-v8a` em `ro.product.cpu.abilist`, mas não executam ELF ARM64 standalone no shell.

### Instalação manual equivalente

```bash
mkdir -p /tmp/python-android-x86_64
tar -xzf output/dist/python-android-x86_64-minimal.tar.gz -C /tmp/python-android-x86_64
docker exec android-15 sh -lc 'rm -rf /data/local/tmp/x86_64/python-android-x86_64 && mkdir -p /data/local/tmp/x86_64/python-android-x86_64'
docker cp /tmp/python-android-x86_64/. android-15:/data/local/tmp/x86_64/python-android-x86_64
docker exec android-15 sh -lc "cat > /system/bin/python3 <<'EOF'
#!/system/bin/sh
exec /data/local/tmp/x86_64/python-android-x86_64/bin/python3 \"\$@\"
EOF
chmod 0755 /system/bin/python3
ln -sf /system/bin/python3 /system/bin/python
cat > /system/bin/pip <<'EOF'
#!/system/bin/sh
exec /data/local/tmp/x86_64/python-android-x86_64/bin/python3 -m pip \"\$@\"
EOF
chmod 0755 /system/bin/pip"
```

### Instalação com ADB

Exemplo para `x86_64`:

```bash
rm -rf /tmp/python-android-x86_64
mkdir -p /tmp/python-android-x86_64
tar -xzf output/dist/python-android-x86_64-minimal.tar.gz -C /tmp/python-android-x86_64
adb shell 'rm -rf /data/local/tmp/x86_64/python-android-x86_64 && mkdir -p /data/local/tmp/x86_64/python-android-x86_64'
adb push /tmp/python-android-x86_64/. /data/local/tmp/x86_64/python-android-x86_64/
adb shell 'cat > /data/local/tmp/python3 <<'\''EOF'\''
#!/system/bin/sh
exec /data/local/tmp/x86_64/python-android-x86_64/bin/python3 "$@"
EOF
chmod 0755 /data/local/tmp/python3
ln -sf /data/local/tmp/python3 /data/local/tmp/python'
adb shell '/data/local/tmp/python3 --version'
adb shell '/data/local/tmp/python3 -c "import numpy, pandas, uiautomator2; from PIL import Image; from lxml import etree; print(numpy.__version__, pandas.__version__, Image.__version__)"'
```

Se o dispositivo tiver root/remount e você quiser wrappers globais:

```bash
adb root
adb remount
adb shell 'cat > /system/bin/python3 <<'\''EOF'\''
#!/system/bin/sh
exec /data/local/tmp/x86_64/python-android-x86_64/bin/python3 "$@"
EOF
chmod 0755 /system/bin/python3
ln -sf /system/bin/python3 /system/bin/python
cat > /system/bin/pip <<'\''EOF'\''
#!/system/bin/sh
exec /data/local/tmp/x86_64/python-android-x86_64/bin/python3 -m pip "$@"
EOF
chmod 0755 /system/bin/pip'
adb shell 'python3 --version'
```

Habilitar `pip` via ADB:

```bash
adb shell '/data/local/tmp/x86_64/python-android-x86_64/bin/python3 -m ensurepip --default-pip'
adb shell '/data/local/tmp/x86_64/python-android-x86_64/bin/python3 -m pip --version'
adb shell '/data/local/tmp/x86_64/python-android-x86_64/bin/python3 -m pip install urllib3'
```

## Como testar no Android

Rodar a suíte de validação:

```bash
./scripts/redroid-test.sh
```

Atalho com `make`:

```bash
make redroid-test
```

O teste valida:

- `python3 --version`
- `print("hello from android")`
- `import json, ssl, sqlite3, ctypes`
- `sys.path`
- criação de arquivo temporário
- execução de script externo
- socket + TLS real
- `HTTPS GET` real
- wrappers em `/system/bin/python3` e `/system/bin/python`
- imports de `faker`, `requests`, `jinja2`, `numpy`, `pandas`, `Pillow`, `lxml` e `uiautomator2`

## Como usar pip no Android

Habilitar `pip` no runtime:

```bash
./scripts/redroid-enable-pip.sh
```

Testar instalação de pacote pure-Python:

```bash
./scripts/redroid-pip-install.sh urllib3
```

Atalho com `make`:

```bash
make redroid-pip
```

## Pacotes já inclusos no build

Além da stdlib principal, o build agora inclui:

- `faker`
- `requests`
- `jinja2`
- `numpy`
- `pandas`
- `Pillow`
- `lxml`
- `uiautomator2`

Dependências puras instaladas junto:

- `urllib3`
- `certifi`
- `idna`
- `charset-normalizer`
- `MarkupSafe`
- `python-dateutil`
- `pytz`
- `tzdata`

### Pacotes nativos: numpy, pandas, Pillow, lxml e uiautomator2

`numpy`, `pandas`, `Pillow` e `lxml` têm extensões nativas. `uiautomator2` é puro, mas depende de wheels Android nativas como `Pillow` e `lxml`, então também é instalado pelo fluxo de pacotes nativos.

O fluxo padrão agora compila essas wheels dentro do builder com `crossenv`, Meson e o Android NDK:

```bash
make native-wheels
make native-packages
make package
make export
```

No build completo, essa sequência já é chamada por:

```bash
make build
```

As wheels geradas ficam em:

```text
output/wheelhouse/<abi>/
```

Exemplo para `x86_64`:

```text
output/wheelhouse/x86_64/numpy-...-cp312-cp312-android_24_x86_64.whl
output/wheelhouse/x86_64/pandas-...-cp312-cp312-android_24_x86_64.whl
```

Exemplo para `arm64-v8a`:

```text
output/wheelhouse/arm64-v8a/numpy-...-cp312-cp312-android_24_arm64_v8a.whl
output/wheelhouse/arm64-v8a/pandas-...-cp312-cp312-android_24_arm64_v8a.whl
```

Também é possível sobrescrever:

- `ANDROID_WHEELHOUSE_DIR`: diretório das wheels nativas.
- `ANDROID_WHEEL_PLATFORM_TAG`: tag de plataforma usada pelo `pip`, por exemplo `android_24_x86_64`.
- `NUMPY_VERSION`: versão pinada do `numpy`.
- `PANDAS_VERSION`: versão pinada do `pandas`.
- `PILLOW_VERSION`: versão pinada do `Pillow`.
- `LXML_VERSION`: versão pinada do `lxml`.
- `UIAUTOMATOR2_VERSION`: versão pinada do `uiautomator2`.

Se quiser usar wheels próprias em vez de compilar, coloque-as em `output/wheelhouse/<abi>/` antes de rodar `make native-packages`.

O staging gera também:

- `BUNDLED-PACKAGES.txt`

Esse arquivo vai dentro do runtime final e registra as versões empacotadas.

## Exemplo de uso no Android

Depois do deploy:

```bash
docker exec android-15 sh -lc 'python3 --version'
docker exec android-15 sh -lc 'python --version'
docker exec android-15 sh -lc 'pip --version'
docker exec android-15 sh -lc 'python3 -c "import sys; print(sys.version)"'
docker exec android-15 sh -lc 'python3 -c "import json, ssl, sqlite3, ctypes; print(\"ok\")"'
```

## Limitações conhecidas

- Não é binário único/estático.
- O formato robusto é launcher + `libpython` + stdlib + `lib-dynload`.
- `pip` no Android foi validado para pacotes pure-Python.
- Pacotes com dependências nativas podem exigir cross-build adicional.
- `readline`, `curses`, `tkinter`, `dbm/gdbm` e afins não fazem parte do perfil atual.

## Limpeza do workspace

Limpar build, staging, runtime e dist:

```bash
make clean
```

Limpeza mais agressiva, incluindo downloads e cache local:

```bash
make distclean
```

## GitHub Actions

Workflows incluídos:

- `.github/workflows/build.yml`
- `.github/workflows/release.yml`

Convenção sugerida para tags:

```text
android-python-py3.12.12-r1
android-python-py3.12.12-r2
```

## Fluxo recomendado

1. `make compose-build`
2. `make compose-up`
3. `make build`
4. `make redroid-push`
5. `make redroid-test`
6. `make redroid-pip`
