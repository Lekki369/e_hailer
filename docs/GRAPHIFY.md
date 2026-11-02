# Structural code map

Graphify indexes handwritten Flutter/server code, tests, Python build/security tools, the web notification worker and first-party Markdown headings. It excludes generated contracts, native/vendor directories, generated Firebase worker configuration, dependencies and secrets. The handwritten environment-backed Firebase options contain setting names only and are included. It makes **no LLM calls** and does not claim semantic document analysis or runtime correctness.

Install the pinned tool environment:

```sh
uv venv .cache/graphify-env --python 3.13
uv pip install --python .cache/graphify-env/bin/python -r tool/requirements-graphify.txt
```

Run the script with Graphify's Python, not a generic interpreter without its dependencies:

```sh
.cache/graphify-env/bin/python tool/graphify_update.py
GRAPHIFY_NO_AUTO_REFRESH=1 .cache/graphify-env/bin/graphify tree --graph graphify-out/graph.json --output docs/codebase-map.html --root . --label e-Hailer
```

After the first refresh, `graphify-out/.graphify_python` records the local interpreter:

```sh
"$(cat graphify-out/.graphify_python)" tool/graphify_update.py
GRAPHIFY_NO_AUTO_REFRESH=1 .cache/graphify-env/bin/graphify query "OperationsApi" --graph graphify-out/graph.json
GRAPHIFY_NO_AUTO_REFRESH=1 .cache/graphify-env/bin/graphify affected "OperationsService" --graph graphify-out/graph.json
```

Outputs are `graphify-out/graph.json`, `GRAPH_REPORT.md`, a source-hash manifest and the [interactive tree](codebase-map.html). Community names derive from current membership; they are not reused by numeric ID. The tree uses D3 and may require internet access for viewer dependencies. Disable CLI auto-refresh with `GRAPHIFY_NO_AUTO_REFRESH=1` so other projects' agent skills stay untouched. Never run an installer that rewrites the preserved root `AGENTS.md`.

The [Archify overview](architecture.html) explains trust and runtime ownership. Graphify provides symbol navigation and structural change-impact hints; verify suggested edges at the source before editing.
