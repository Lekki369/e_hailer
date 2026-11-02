#!/usr/bin/env python3
"""Rebuild the structural Graphify map without LLM calls or repository-wide scanning."""
import os
import sys
from pathlib import Path
if os.environ.get('PYTHONHASHSEED') != '0':
    os.environ['PYTHONHASHSEED'] = '0'
    os.execv(sys.executable, [sys.executable, *sys.argv])
import hashlib
import json
from collections import Counter
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.export import to_json
from graphify.extract import extract
from graphify.report import generate

ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
OUT = Path('graphify-out')
OUT.mkdir(exist_ok=True)
SCOPE = ('lib', 'test', 'server/ehailer_server/lib', 'server/ehailer_server/test', 'tool', 'web')
def allowed(path):
    return not any(part in {'generated','test_tools','node_modules','.dart_tool','__pycache__'} for part in path.parts) and path.name != 'firebase-client-config.js'
code = sorted({p for directory in SCOPE for p in Path(directory).rglob('*') if p.is_file() and p.suffix in {'.dart','.js','.py'} and allowed(p)})
# Deterministic AST structure, deliberately excluding generated SDK/vendor code.
extraction = extract(code, cache_root=Path('.cache/graphify'), parallel=False)
docs = [Path('README.md'), Path('SECURITY.md'), *sorted(Path('docs').glob('*.md'))]
for path in docs:
    node_id = 'document_' + hashlib.sha256(str(path).encode()).hexdigest()[:16]
    extraction['nodes'].append({'id':node_id,'label':path.name,'file_type':'document','source_file':str(path),'source_location':None})
    for number, line in enumerate(path.read_text().splitlines(),1):
        if line.startswith('#') and ' ' in line:
            heading_id = f'{node_id}_{number}'
            extraction['nodes'].append({'id':heading_id,'label':line.lstrip('# ').strip(),'file_type':'document','source_file':str(path),'source_location':number})
            extraction['edges'].append({'source':node_id,'target':heading_id,'relation':'contains_heading','confidence':'EXTRACTED','confidence_score':1.0,'source_file':str(path),'weight':1.0})
G = build_from_json(extraction)
communities = cluster(G)
labels = {}
for cid, members in communities.items():
    counts = Counter((G.nodes[n].get('source_file') or 'External symbols') for n in sorted(members))
    labels[cid] = Path(counts.most_common(1)[0][0]).stem.replace('_',' ').title()
to_json(G,communities,str(OUT/'graph.json'),force=True)
report = generate(G,communities,score_all(G,communities),labels,[],[],{'total_files':len(code)+len(docs),'total_words':0,'files':{'code':list(map(str,code)),'document':list(map(str,docs))}},{'input_tokens':0,'output_tokens':0},str(ROOT))
(OUT/'GRAPH_REPORT.md').write_text('# Structural map only\n\nAST symbols, references and Markdown headings; no semantic LLM extraction or runtime proof. Generated client/server contracts are intentionally excluded.\n\n'+report)
(OUT/'.graphify_python').write_text(sys.executable+'\n')
(OUT/'.graphify_labels.json').write_text(json.dumps({str(k):v for k,v in labels.items()},indent=2)+'\n')
manifest = {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in code+docs}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
print(f'{len(code)} code files, {len(docs)} documents; {G.number_of_nodes()} nodes and {G.number_of_edges()} edges')
