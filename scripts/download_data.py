# -*- coding: utf-8 -*-
"""下载 Lending Club 信贷数据到 data 目录（断点续传、带进度）"""
import os
import sys
import urllib.request

URL = "https://h2o-public-test-data.s3.amazonaws.com/bigdata/laptop/lending-club/LoanStats3a.csv"
DEST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "LoanStats3a.csv")


def download(url: str, dest: str) -> None:
    tmp = dest + ".part"
    downloaded = 0
    if os.path.exists(tmp):
        downloaded = os.path.getsize(tmp)
    headers = {"Range": f"bytes={downloaded}-"} if downloaded else {}

    req = urllib.request.Request(url, headers=headers)
    total = None
    with urllib.request.urlopen(req, timeout=120) as resp:
        if downloaded == 0:
            total = int(resp.headers.get("Content-Length", 0))
        else:
            content_range = resp.headers.get("Content-Range", "")
            if "/" in content_range:
                total = int(content_range.split("/")[-1])
        mode = "ab" if downloaded else "wb"
        with open(tmp, mode) as f:
            while True:
                chunk = resp.read(1024 * 512)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
                if total:
                    pct = downloaded * 100.0 / total
                    print(f"\r{downloaded/1024/1024:.2f} MB / {total/1024/1024:.2f} MB ({pct:.1f}%)", end="", flush=True)
    print()
    os.replace(tmp, dest)
    print(f"完成: {dest} ({os.path.getsize(dest)/1024/1024:.2f} MB)")


if __name__ == "__main__":
    try:
        download(URL, DEST)
    except Exception as e:
        print(f"下载失败: {e}", file=sys.stderr)
        sys.exit(1)
