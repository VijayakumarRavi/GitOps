#!/usr/bin/env python3
import sys
from pathlib import Path
from ruamel.yaml import YAML

def process_file(filepath):
    yaml = YAML()
    yaml.preserve_quotes = True
    try:
        with open(filepath, 'r') as f:
            docs = list(yaml.load_all(f))
    except Exception as e:
        return
        
    for doc in docs:
        def traverse(node):
            if not isinstance(node, dict):
                return
            keys = list(node.keys())
            items = [(k, node[k]) for k in keys]
            try:
                node.clear()
                for k, v in items:
                    node[k] = v
            except Exception as e:
                print(f"FAILED on file {filepath}: {e}")
                sys.exit(1)
            for v in node.values():
                traverse(v)
                
        traverse(doc)

target_dir = Path("kubernetes")
for filepath in target_dir.rglob("*.yaml"):
    process_file(filepath)
