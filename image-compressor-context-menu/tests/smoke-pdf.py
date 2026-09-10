from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import pymupdf


root = Path(tempfile.mkdtemp(prefix="pdf-compressor-test-"))
input_path = root / "sample.pdf"
wrapper = Path(__file__).resolve().parents[1] / "compress-pdf.ps1"

try:
    document = pymupdf.open()
    for page_number in range(8):
        page = document.new_page()
        for line in range(500):
            page.insert_text(
                (48, 48 + (line % 40) * 12),
                f"PDF compression smoke test page={page_number} line={line % 10} repeated text",
                fontsize=8,
            )
    document.save(str(input_path), garbage=0, deflate=False)
    document.close()

    input_bytes = input_path.stat().st_size
    completed = subprocess.run(
        [
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(wrapper),
            "-InputPath",
            str(input_path),
            "-Json",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    result = json.loads(completed.stdout.strip())
    if not result["Ok"]:
        raise AssertionError(result["Message"])
    output_path = Path(result["OutputPath"])
    if not output_path.is_file():
        raise AssertionError(f"output missing: {output_path}")
    output_bytes = output_path.stat().st_size
    if output_bytes >= input_bytes:
        raise AssertionError(f"output is not smaller: {input_bytes} -> {output_bytes}")
    check = pymupdf.open(str(output_path))
    try:
        if len(check) != 8:
            raise AssertionError(f"page count changed: {len(check)}")
    finally:
        check.close()
    print(f"PASS: {input_bytes} -> {output_bytes}, pages=8")
finally:
    shutil.rmtree(root, ignore_errors=True)
