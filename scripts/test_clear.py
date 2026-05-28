import sys
from ruamel.yaml import YAML

yaml_str = """
route:
  photos: &route
    b: 2 # comment b
    a: 1 # comment a
  api:
    <<: *route
    c: 3
"""

yaml = YAML()
doc = yaml.load(yaml_str)

node = doc['route']['photos']
keys = list(node.keys())
keys.sort()

# Trying clear and update
items = [(k, node[k]) for k in keys]
node.clear()
for k, v in items:
    node[k] = v

yaml.dump(doc, sys.stdout)
