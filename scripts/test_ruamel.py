import sys
from ruamel.yaml import YAML

yaml_str = """
b: 2 # comment b
a: 1 # comment a
"""

yaml = YAML()
doc = yaml.load(yaml_str)

print("Before:", doc)
keys = list(doc.keys())
keys.sort()

# Trying to reorder
for k in keys:
    val = doc.pop(k)
    doc[k] = val

yaml.dump(doc, sys.stdout)
