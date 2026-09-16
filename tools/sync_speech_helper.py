"""Run after editing prototype_1/windows_speech.ps1; commit both helper files."""
from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]
source = (root / "prototype_1/windows_speech.ps1").read_text(encoding="utf-8")
(root / "prototype_1/windows_speech_helper.tres").write_text(
    '[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/source = '
    + json.dumps(source, ensure_ascii=False) + '\n', encoding="utf-8"
)
