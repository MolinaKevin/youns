# Tests

## Unitarios

No cargan mapas ni el streaming del mundo; se pueden ejecutar en headless:

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -- -gdir=res://tests/unit -gexit
```

GitHub Actions ejecuta este comando automáticamente en cada pull request y
cambio a `main` (`.github/workflows/tests.yml`).

## Integración del mundo

Los tests de `tests/integration/` cargan los `.glb`, construyen la grilla y
verifican zonas, pisos, guardado y decoración. Ejecutarlos en una sesión con
renderer gráfico, no con `--headless`, porque los modelos 3D importados no son
compatibles con el renderer dummy de Godot:

```bash
godot --path . -s res://addons/gut/gut_cmdln.gd -- -gdir=res://tests/integration -gexit
```

Si se ejecutan por error en headless, los casos gráficos se omiten de forma
explícita en lugar de intentar crear meshes con el renderer dummy.

`ZoneManager` detecta GUT y no inicializa el exterior automáticamente. Cada
test de integración lo habilita explícitamente en `before_all()`.
