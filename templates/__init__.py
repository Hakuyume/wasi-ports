import os
import sys

import wasmtime


def main() -> int:
    engine = wasmtime.Engine()

    linker = wasmtime.Linker(engine)
    linker.define_wasi()

    store = wasmtime.Store(engine)
    wasi = wasmtime.WasiConfig()
    wasi.argv = sys.argv
    wasi.inherit_stderr()
    wasi.inherit_stdin()
    wasi.inherit_stdout()
    wasi.preopen_dir(os.getcwd(), os.getcwd())
    store.set_wasi(wasi)

    module = wasmtime.Module.from_file(
        engine,
        os.path.join(os.path.dirname(__file__), "main.wasm"),
    )
    instance = linker.instantiate(store, module)
    start = instance.exports(store)["_start"]
    try:
        start(store)
        return 0
    except wasmtime.ExitTrap as e:
        return e.code
