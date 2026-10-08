#!/usr/bin/env python3
"""Check that literal SwiftUI copy has a Simplified Chinese translation."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STRINGS_FILE = ROOT / "WrapPin/Resources/zh-Hans.lproj/Localizable.strings"
SWIFT_ROOT = ROOT / "WrapPin"
NATIVE_ROOT = ROOT / "Native/WrapPinPairingFFI"

STRINGS_KEY = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=')
LOCALIZED_CALLS = re.compile(
    r'(?:String\(localized:|NSLocalizedString\(|Text\(|Label\(|Button\(|Toggle\('
    r'|Section\(|LabeledContent\(|Picker\(|\.navigationTitle\(|\.alert\('
    r'|\.confirmationDialog\(|\.accessibilityLabel\(|\.accessibilityHint\()'
    r'\s*"((?:\\.|[^"\\])*)"'
)
# Rust user-facing messages: owned strings, coordinate validation and the
# location engine's structured errors.
NATIVE_MESSAGES = re.compile(
    r'"([^"\n]+)"\.to_string\(\)'
    r'|\bErr\(\s*"([^"\n]+)"\s*\)'
    r'|LocationError::(?:new|recoverable)\(\s*[\w:]+,\s*"([^"\n]+)"'
)


def load_keys() -> tuple[set[str], list[str]]:
    keys: list[str] = []
    for line in STRINGS_FILE.read_text(encoding="utf-8").splitlines():
        match = STRINGS_KEY.match(line)
        if match:
            keys.append(match.group(1))
    duplicates = sorted(key for key, count in Counter(keys).items() if count > 1)
    return set(keys), duplicates


def find_required_keys() -> dict[str, set[str]]:
    required: dict[str, set[str]] = {}
    for path in sorted(SWIFT_ROOT.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in LOCALIZED_CALLS.finditer(text):
            key = match.group(1)
            if "\\(" in key:
                continue
            required.setdefault(key, set()).add(str(path.relative_to(ROOT)))

    for path in sorted(NATIVE_ROOT.rglob("*.rs")):
        text = path.read_text(encoding="utf-8")
        text = text.split("#[cfg(test)]")[0]
        for match in NATIVE_MESSAGES.finditer(text):
            key = next(group for group in match.groups() if group)
            required.setdefault(key, set()).add(str(path.relative_to(ROOT)))
    return required


def main() -> int:
    keys, duplicates = load_keys()
    required = find_required_keys()
    missing = sorted(set(required) - keys)

    if duplicates:
        print("Duplicate localization keys:")
        for key in duplicates:
            print(f"  {key}")

    if missing:
        print("Missing zh-Hans localization keys:")
        for key in missing:
            locations = ", ".join(sorted(required[key]))
            print(f"  {key} [{locations}]")

    if duplicates or missing:
        return 1

    print(f"Localization check passed: {len(keys)} zh-Hans keys cover {len(required)} literal UI keys.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
