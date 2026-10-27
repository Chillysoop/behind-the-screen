# Build the Streamlined edition

This creates a separate **Behind the Screen - Streamlined** application using the original Defold project and assets. It layers `streamlined.ini` over `game.project` and enables `streamlined.enabled = 1`.

## Requirements

- Python 3.9 or newer.
- Java 25 ([Adoptium](https://adoptium.net/temurin/releases/?version=25)).
- Official [Defold 1.13.2 bob.jar](https://github.com/defold/defold/releases/download/1.13.2/bob.jar).

## Windows package

From the project root:

```sh
python tools/build/build_streamlined.py --bob /path/to/bob.jar --java /path/to/java --target windows
```

On Windows, provide the paths to `bob.jar` and `java.exe`. The Defold editor's bundled Java 25 can also be used. `BOB` and `JAVA` environment variables are accepted.

The distributable ZIP is `dist/streamlined/Behind-the-Screen-Streamlined-windows.zip`. Extract the entire archive and open its `.exe`.

## Additional targets

```sh
python tools/build/build_streamlined.py --bob /path/to/bob.jar --java /path/to/java --target linux
python tools/build/build_streamlined.py --bob /path/to/bob.jar --java /path/to/java --target html5
python tools/build/build_streamlined.py --bob /path/to/bob.jar --java /path/to/java --target all
```

HTML5 is the same Defold game compiled to WebAssembly. Extract its ZIP and run `python serve_local.py` inside the application folder. It opens a local server on `127.0.0.1:8000`; it does not publish or upload the game. Opening `index.html` directly does not work.

## Outputs

- Separate per-platform build cache and logs: `build/streamlined/`.
- Application folders, ZIP packages, and SHA-256 manifest: `dist/streamlined/`.
- Release builds by default; pass `--variant debug` for development.
- `--clean` cleans only the selected edition's build cache.

The packaging step includes the SRD attribution and font licenses. Generated bundles are build outputs and should not be committed.
