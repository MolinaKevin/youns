# Tests

## Unitarios

No cargan mapas ni el streaming del mundo; se pueden ejecutar en headless:

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -- -gdir=res://tests/unit -gexit
```

GitHub Actions ejecuta este comando automáticamente en cada pull request y
cambio a `main` (`.github/workflows/tests.yml`). La ejecución tiene un límite
de cinco minutos (y el job, diez): así un test que se quede esperando no deja
el CI colgado indefinidamente.

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

CI ejecuta esta suite con un display virtual (`Xvfb`) y el renderer OpenGL;
tiene un límite de diez minutos (quince para el job). Así los mapas, la grilla
del mundo y las escenas 3D se validan también antes de integrar un cambio.

`test_youn_interaction.gd` también vive en esta suite: usa los modelos y las
animaciones reales del jugador y del Youn.

`ZoneManager` detecta GUT y no inicializa el exterior automáticamente. Cada
test de integración lo habilita explícitamente en `before_all()`.
