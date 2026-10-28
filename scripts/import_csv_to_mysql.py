# -*- coding: utf-8 -*-
"""
信贷数据快速导入脚本（秒级批量导入）
用法:
  1) PowerShell 里先设置密码环境变量:  $env:MYSQL_PWD = '你的root密码'
  2) 再运行:                          python scripts/import_csv_to_mysql.py
说明: 自动建库建表并批量导入；跑完关掉窗口，密码不留痕
依赖: pip install pymysql
"""
import csv
import os
import sys

import pymysql

CSV_PATH = r"C:\Users\35729\credit-warehouse\data\LoanStats3a.csv"
DB_HOST = "127.0.0.1"
DB_PORT = 3306
DB_USER = "root"
DB_NAME = "src"
TABLE = "loan_raw"
BATCH = 5000  # 每批插入行数


def main():
    # 1. 读 CSV 表头（第一行）
    with open(CSV_PATH, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = list(reader)
    # 1.1 字段补齐：某些行可能字段不足 52 个（脏数据），缺失补空字符串
    n = len(header)
    fixed = 0
    norm = []
    for row in rows:
        if len(row) != n:
            fixed += 1
            row = row + [""] * (n - len(row)) if len(row) < n else row[:n]
        norm.append(row)
    rows = norm
    print(f"CSV: {len(header)} 列, {len(rows)} 行数据, 补齐异常行 {fixed} 行", flush=True)

    # 2. 从环境变量读密码（避免交互式输入失败）
    password = os.environ.get("MYSQL_PWD", "")
    if not password:
        print("错误: 请先设置密码环境变量: $env:MYSQL_PWD = '你的root密码'", flush=True)
        sys.exit(1)

    # 3. 连接数据库
    conn = pymysql.connect(
        host=DB_HOST, port=DB_PORT, user=DB_USER, password=password,
        charset="utf8mb4", autocommit=True,
    )
    cursor = conn.cursor()

    # 4. 建库 + 建表（全部字段用 TEXT 原样落库，避免长文本超长，Day 3 再清洗转类型）
    cols = ", ".join(f"`{c}` TEXT" for c in header)
    cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}`")
    cursor.execute(f"USE `{DB_NAME}`")
    cursor.execute(f"DROP TABLE IF EXISTS `{TABLE}`")
    cursor.execute(f"CREATE TABLE `{TABLE}` ({cols}) ENGINE=InnoDB")

    # 5. 分批批量插入
    placeholders = ", ".join(["%s"] * len(header))
    sql = f"INSERT INTO `{TABLE}` ({', '.join('`' + c + '`' for c in header)}) VALUES ({placeholders})"
    total = 0
    for i in range(0, len(rows), BATCH):
        batch = rows[i : i + BATCH]
        cursor.executemany(sql, batch)
        total += len(batch)
        print(f"已插入 {total} 行...")

    print(f"完成! 共插入 {total} 行")

    # 6. 验证
    cursor.execute(f"SELECT COUNT(*) FROM `{TABLE}`")
    print(f"验证 COUNT(*): {cursor.fetchone()[0]}")

    cursor.close()
    conn.close()


if __name__ == "__main__":
    try:
        main()
    except pymysql.err.MySQLError as e:
        print(f"数据库错误: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)
