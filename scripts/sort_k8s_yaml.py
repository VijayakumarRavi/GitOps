#!/usr/bin/env python3
import sys
from pathlib import Path
from ruamel.yaml import YAML

K8S_TOP_LEVEL = ['apiVersion', 'kind', 'metadata', 'spec']
METADATA_ORDER = ['name', 'namespace', 'annotations', 'labels']
APP_TEMPLATE_SPEC = ['chartRef', 'interval', 'dependsOn', 'install', 'upgrade', 'values']

def sort_node(node, path, is_app_tmpl):
    if not isinstance(node, dict):
        return

    keys = list(node.keys())
    p = ".".join(path)
    skip_sort_keys = False
    
    if is_app_tmpl:
        if p in ['spec.values.persistence', 'spec.values.service', 'spec.values.route', 'spec.values.controllers', 'spec.values.configMaps']:
            skip_sort_keys = True

    if not skip_sort_keys:
        # Sort keys safely if there are mixed types by converting to string for alphabetical sort
        keys.sort(key=lambda x: str(x))
        
        order_list = []
        
        if len(path) == 0:
            order_list = K8S_TOP_LEVEL
        elif len(path) == 1 and path[0] == 'metadata':
            order_list = METADATA_ORDER
            
        if is_app_tmpl:
            if 'enabled' in keys:
                order_list.append('enabled')
                
            if len(path) == 1 and path[0] == 'spec':
                order_list.extend(APP_TEMPLATE_SPEC)
            elif p == 'spec.values':
                order_list.extend(['defaultPodOptions'])
            elif p.startswith('spec.values.controllers.') and len(path) == 4:
                order_list.extend(['type', 'annotations', 'labels', 'cronjob', 'statefulset', 'pod'])
            elif p.startswith('spec.values.controllers.') and len(path) == 6 and path[4] in ['containers', 'initContainers']:
                order_list.extend(['image'])
            elif p.startswith('spec.values.controllers.') and len(path) == 7 and path[4] in ['containers', 'initContainers'] and path[6] == 'resources':
                order_list.extend(['requests', 'limits'])
            elif p.startswith('spec.values.service.') and len(path) == 4:
                order_list.extend(['type', 'annotations', 'labels'])
            elif p.startswith('spec.values.persistence.') and len(path) == 4:
                order_list.extend(['type', 'annotations', 'labels'])
            else:
                if 'annotations' not in order_list:
                    order_list.append('annotations')
                if 'labels' not in order_list:
                    order_list.append('labels')

        def sort_key(k):
            if is_app_tmpl:
                if p.startswith('spec.values.controllers.') and len(path) == 4:
                    if k == 'initContainers': return 10000
                    if k == 'containers': return 10001
                if p.startswith('spec.values.persistence.') and len(path) == 4:
                    if k == 'globalMounts': return 10000
                    if k == 'advancedMounts': return 10001
            try:
                return order_list.index(k)
            except ValueError:
                return len(order_list)

        keys.sort(key=sort_key)

        # Clear the dict and add items back in sorted order
        sorted_items = [(k, node[k]) for k in keys]
        node.clear()
        for k, v in sorted_items:
            node[k] = v

    for k, v in node.items():
        new_path = path + [str(k)]
        if isinstance(v, dict):
            sort_node(v, new_path, is_app_tmpl)
        elif isinstance(v, list):
            for item in v:
                if isinstance(item, dict):
                    sort_node(item, new_path, is_app_tmpl)

def process_file(filepath):
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)
    yaml.width = 4096
    
    try:
        with open(filepath, 'r') as f:
            docs = list(yaml.load_all(f))
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return False
        
    modified = False
    for doc in docs:
        if not doc:
            continue
            
        app_tmpl = False
        try:
            if isinstance(doc, dict):
                if doc.get('kind') == 'HelmRelease' and doc.get('spec', {}).get('chartRef', {}).get('name') == 'app-template':
                    app_tmpl = True
        except AttributeError:
            pass
            
        sort_node(doc, [], app_tmpl)
        modified = True
        
    if modified:
        try:
            with open(filepath, 'w') as f:
                yaml.dump_all(docs, f)
            return True
        except Exception as e:
            print(f"Error writing {filepath}: {e}")
    return False

def main():
    target_dir = Path("kubernetes")
    if not target_dir.exists():
        print("kubernetes directory not found!")
        sys.exit(1)
        
    success_count = 0
    fail_count = 0
    for filepath in target_dir.rglob("*.yaml"):
        if process_file(filepath):
            success_count += 1
        else:
            fail_count += 1
            
    print(f"Successfully processed {success_count} files.")
    if fail_count > 0:
        print(f"Failed to process {fail_count} files.")

if __name__ == "__main__":
    main()
