\
    #!/usr/bin/env python3
    """
    Yozgat / Sorgun için NVI kaynaklı eski dump'tan mahalle/köy + cadde/sokak verisini çıkarır.
    Kullanım:
      1) GitHub reposundaki SQLite zip dosyasını indir:
         https://github.com/emreuenal/turkiye-il-ilce-sokak-mahalle-veri-tabani/tree/master/dumps
      2) Örnek:
         python sorgun_uavt_extract.py --db tr_adres_sqlite_11052020.db --out sorgun_adres
    Not: Bu dump 2020/2021 tabanlı olabilir. Prod uygulamada güncel NVI/MAKS veya lisanslı adres API ile doğrula.
    """
    import argparse
    import csv
    import json
    import sqlite3
    from pathlib import Path

    def rows_to_dicts(cursor, rows):
        cols = [d[0] for d in cursor.description]
        return [dict(zip(cols, row)) for row in rows]

    def main():
        parser = argparse.ArgumentParser()
        parser.add_argument("--db", required=True, help="SQLite .db dosyası")
        parser.add_argument("--out", default="sorgun_adres", help="Çıktı dosya öneki")
        args = parser.parse_args()

        db_path = Path(args.db)
        if not db_path.exists():
            raise SystemExit(f"DB bulunamadı: {db_path}")

        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()

        cur.execute("""
            SELECT il_adi, ilce_adi, mahalle_id, mahalle_adi
            FROM mahalleler
            WHERE UPPER(il_adi) = 'YOZGAT'
              AND UPPER(ilce_adi) = 'SORGUN'
            ORDER BY mahalle_adi
        """)
        mahalleler = rows_to_dicts(cur, cur.fetchall())

        cur.execute("""
            SELECT il_adi, ilce_adi, mahalle_id, mahalle_adi, sokak_id, sokak_adi
            FROM sokaklar
            WHERE UPPER(il_adi) = 'YOZGAT'
              AND UPPER(ilce_adi) = 'SORGUN'
            ORDER BY mahalle_adi, sokak_adi
        """)
        sokaklar = rows_to_dicts(cur, cur.fetchall())

        grouped = {}
        for m in mahalleler:
            grouped[m["mahalle_adi"]] = {
                "mahalle_id": m["mahalle_id"],
                "mahalle_adi": m["mahalle_adi"],
                "cadde_sokaklar": []
            }

        for s in sokaklar:
            key = s["mahalle_adi"]
            grouped.setdefault(key, {
                "mahalle_id": s["mahalle_id"],
                "mahalle_adi": key,
                "cadde_sokaklar": []
            })
            grouped[key]["cadde_sokaklar"].append({
                "sokak_id": s["sokak_id"],
                "sokak_adi": s["sokak_adi"]
            })

        out_prefix = Path(args.out)

        with open(f"{out_prefix}_mahalleler.csv", "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=["il_adi", "ilce_adi", "mahalle_id", "mahalle_adi"])
            writer.writeheader()
            writer.writerows(mahalleler)

        with open(f"{out_prefix}_cadde_sokaklar.csv", "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=["il_adi", "ilce_adi", "mahalle_id", "mahalle_adi", "sokak_id", "sokak_adi"])
            writer.writeheader()
            writer.writerows(sokaklar)

        with open(f"{out_prefix}_grouped.json", "w", encoding="utf-8") as f:
            json.dump(list(grouped.values()), f, ensure_ascii=False, indent=2)

        print(f"Mahalle/köy/mevki kayıtları: {len(mahalleler)}")
        print(f"Cadde/sokak/bulvar/meydan kayıtları: {len(sokaklar)}")
        print(f"Çıktılar: {out_prefix}_mahalleler.csv, {out_prefix}_cadde_sokaklar.csv, {out_prefix}_grouped.json")

    if __name__ == "__main__":
        main()
