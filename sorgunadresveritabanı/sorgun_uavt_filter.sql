-- emreuenal/turkiye-il-ilce-sokak-mahalle-veri-tabani SQLite dump içindir.
-- Amaç: Yozgat / Sorgun için mahalle-köy-mezra-mevki ve cadde-sokak-bulvar-meydan kayıtlarını çekmek.

-- Mahalle / köy / mezra / mevki kayıtları
SELECT
  il_adi,
  ilce_adi,
  mahalle_id,
  mahalle_adi
FROM mahalleler
WHERE UPPER(il_adi) = 'YOZGAT'
  AND UPPER(ilce_adi) = 'SORGUN'
ORDER BY mahalle_adi;

-- Mahalle -> cadde/sokak/bulvar/meydan kayıtları
SELECT
  il_adi,
  ilce_adi,
  mahalle_id,
  mahalle_adi,
  sokak_id,
  sokak_adi
FROM sokaklar
WHERE UPPER(il_adi) = 'YOZGAT'
  AND UPPER(ilce_adi) = 'SORGUN'
ORDER BY mahalle_adi, sokak_adi;
