with open(".github/workflows/ci.yml") as f:
    text = f.read()

text = text.replace('CURRENT_VERSION=$(echo -e "$PUBSPEC_VERSION          \n\n  $HIGHEST_TAG" | sort -V | tail -n 1)', 'CURRENT_VERSION=$(echo -e "$PUBSPEC_VERSION\\n$HIGHEST_TAG" | sort -V | tail -n 1)')
# and another possible newline injection:
text = text.replace('CURRENT_VERSION=$(echo -e "$PUBSPEC_VERSION          \n\n$HIGHEST_TAG" | sort -V | tail -n 1)', 'CURRENT_VERSION=$(echo -e "$PUBSPEC_VERSION\\n$HIGHEST_TAG" | sort -V | tail -n 1)')

with open(".github/workflows/ci.yml", "w") as f:
    f.write(text)
