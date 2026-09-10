from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path


def output_path(source: Path) -> Path:
    candidate = source.with_name(f"{source.stem}-压缩.pdf")
    index = 2
    while candidate.exists():
        candidate = source.with_name(f"{source.stem}-压缩 ({index}).pdf")
        index += 1
    return candidate


def compress_with_pymupdf(source: Path, temporary: Path) -> int:
    try:
        import pymupdf as fitz
    except ImportError:
        import fitz  # type: ignore

    document = fitz.open(str(source))
    try:
        if getattr(document, "needs_pass", False):
            raise ValueError("PDF 需要密码，未处理")
        pages = len(document)
        document.save(
            str(temporary),
            garbage=4,
            clean=True,
            deflate=True,
            deflate_images=True,
            deflate_fonts=True,
            use_objstms=True,
        )
    finally:
        document.close()

    check = fitz.open(str(temporary))
    try:
        if len(check) != pages:
            raise ValueError("压缩后页数校验失败")
    finally:
        check.close()
    return pages


def compress_with_pypdf(source: Path, temporary: Path) -> int:
    from pypdf import PdfReader, PdfWriter

    reader = PdfReader(str(source), strict=False)
    if reader.is_encrypted and not reader.decrypt(""):
        raise ValueError("PDF 需要密码，未处理")
    writer = PdfWriter()
    for page in reader.pages:
        page.compress_content_streams()
        writer.add_page(page)
    with temporary.open("wb") as output:
        writer.write(output)
    return len(reader.pages)


def compress(source_value: str) -> dict[str, object]:
    temporary: Path | None = None
    try:
        source = Path(source_value).expanduser().resolve()
        if source.suffix.lower() != ".pdf":
            raise ValueError("只支持 PDF 文件")
        if not source.is_file():
            raise FileNotFoundError("文件不存在")

        input_bytes = source.stat().st_size
        destination = output_path(source)
        with tempfile.NamedTemporaryFile(
            prefix=".pdf-compress-", suffix=".pdf", dir=source.parent, delete=False
        ) as temporary_file:
            temporary = Path(temporary_file.name)

        try:
            try:
                pages = compress_with_pymupdf(source, temporary)
                engine = "PyMuPDF"
            except ImportError:
                pages = compress_with_pypdf(source, temporary)
                engine = "pypdf"

            output_bytes = temporary.stat().st_size
            if output_bytes >= input_bytes:
                return {
                    "ok": False,
                    "error": "not_smaller",
                    "input_bytes": input_bytes,
                    "output_bytes": output_bytes,
                    "pages": pages,
                    "engine": engine,
                }
            os.replace(temporary, destination)
            temporary = None
            return {
                "ok": True,
                "input": str(source),
                "output": str(destination),
                "input_bytes": input_bytes,
                "output_bytes": output_bytes,
                "pages": pages,
                "engine": engine,
            }
        finally:
            if temporary and temporary.exists():
                temporary.unlink()
    except Exception as error:
        return {"ok": False, "error": str(error)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = compress(args.input)
    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
