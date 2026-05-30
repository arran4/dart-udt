import yaml
try:
    with open(".github/workflows/ci.yml") as f:
        data = yaml.safe_load(f)
    print("YAML parses correctly!")
except Exception as e:
    print("YAML Parse Error:", e)
