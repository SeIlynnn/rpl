Add-Type -AssemblyName System.IO.Compression.FileSystem

$xlsxPath = Join-Path $PSScriptRoot "..\Rules Book Frontier Lands.xlsx"
$jsonOutPath = Join-Path $PSScriptRoot "..\assets\seed_data.json"
$sqlOutPath = Join-Path $PSScriptRoot "..\supabase_schema.sql"

$zip = [System.IO.Compression.ZipFile]::OpenRead($xlsxPath)
$ssEntry = $zip.GetEntry("xl/sharedStrings.xml")
$ssStrings = @()
if ($ssEntry) {
    $sr = New-Object System.IO.StreamReader($ssEntry.Open())
    [xml]$ssXml = $sr.ReadToEnd()
    $sr.Close()
    foreach ($si in $ssXml.sst.si) {
        if ($null -ne $si.t) {
            if ($si.t -is [string]) { $ssStrings += $si.t }
            else { $ssStrings += $si.t.'#text' }
        } elseif ($si.r) {
            $txt = ($si.r | ForEach-Object { if ($_.t -is [string]) { $_.t } else { $_.t.'#text' } }) -join ""
            $ssStrings += $txt
        } else {
            $ssStrings += ""
        }
    }
}

$wsEntry = $zip.GetEntry("xl/worksheets/sheet1.xml")
$sr = New-Object System.IO.StreamReader($wsEntry.Open())
[xml]$wsXml = $sr.ReadToEnd()
$sr.Close()
$zip.Dispose()

$grid = @{}
foreach ($row in $wsXml.worksheet.sheetData.row) {
    $rNum = [int]$row.r
    $grid[$rNum] = @{}
    foreach ($c in $row.c) {
        $col = ($c.r -replace '[0-9]', '')
        $t = $c.t
        $v = $c.v
        $val = $v
        if ($t -eq "s" -and $null -ne $v) {
            $val = $ssStrings[[int]$v]
        } elseif ($t -eq "inlineStr") {
            $val = $c.is.t
        }
        if ($null -ne $val) {
            $strVal = ($val.ToString() -replace '\s+', ' ').Trim()
            if ($strVal -ne "") {
                $grid[$rNum][$col] = $strVal
            }
        }
    }
}

function Get-Cell($r, $col) {
    if ($grid.ContainsKey($r) -and $grid[$r].ContainsKey($col)) {
        return $grid[$r][$col]
    }
    return $null
}

function To-Int($val) {
    if ($null -eq $val -or $val -eq "") { return $null }
    return [int][math]::Round([double]$val)
}

function To-Float($val) {
    if ($null -eq $val -or $val -eq "") { return $null }
    return [math]::Round([double]$val, 4)
}

# 1. Materials: Rows 4..67, Cols A..G
$materials = @()
$idCounter = 1
for ($r = 4; $r -le 67; $r++) {
    $itemId = To-Int (Get-Cell $r 'B')
    $nama = Get-Cell $r 'C'
    if ($null -eq $itemId -or $null -eq $nama) { continue }
    $materials += [ordered]@{
        id = $idCounter++
        no = To-Int (Get-Cell $r 'A')
        item_id = $itemId
        nama_item = $nama
        rarity = To-Int (Get-Cell $r 'D')
        item_type = Get-Cell $r 'E'
        item_drop = Get-Cell $r 'F'
        object_drop = $null
        persentase = To-Float (Get-Cell $r 'G')
        image_path = $null
    }
}

# 2. Armors: Rows 4..9, Cols I..O
$armors = @()
$idCounter = 1
for ($r = 4; $r -le 9; $r++) {
    $itemId = To-Int (Get-Cell $r 'J')
    $nama = Get-Cell $r 'K'
    if ($null -eq $itemId -or $null -eq $nama) { continue }
    $armors += [ordered]@{
        id = $idCounter++
        no = To-Int (Get-Cell $r 'I')
        item_id = $itemId
        nama_item = $nama
        rarity = To-Int (Get-Cell $r 'L')
        type = Get-Cell $r 'M'
        stats = Get-Cell $r 'N'
        skill = Get-Cell $r 'O'
        image_path = $null
    }
}

# 3. Weapons: Rows 14..29, Cols I..O
$weapons = @()
$idCounter = 1
for ($r = 14; $r -le 29; $r++) {
    $itemId = To-Int (Get-Cell $r 'J')
    $nama = Get-Cell $r 'K'
    if ($null -eq $itemId -or $null -eq $nama) { continue }
    $rawStats = Get-Cell $r 'N'
    $posList = @()
    $negList = @()
    if ($null -ne $rawStats) {
        foreach ($part in ($rawStats -split ',')) {
            $p = $part.Trim()
            if ($p -match '-') { $negList += $p }
            elseif ($p -ne "") { $posList += $p }
        }
    }
    $normalStats = if ($posList.Count -gt 0) { $posList -join ', ' } else { $rawStats }
    $negativeStats = if ($negList.Count -gt 0) { $negList -join ', ' } else { $null }

    $weapons += [ordered]@{
        id = $idCounter++
        no = To-Int (Get-Cell $r 'I')
        item_id = $itemId
        nama_item = $nama
        rarity = To-Int (Get-Cell $r 'L')
        role = Get-Cell $r 'M'
        normal_stats = $normalStats
        negative_stats = $negativeStats
        skill_aktif = Get-Cell $r 'O'
        image_path = $null
    }
}

# 4. Charms: Rows 34..48, Cols I..O
$charms = @()
$idCounter = 1
for ($r = 34; $r -le 48; $r++) {
    $itemId = To-Int (Get-Cell $r 'J')
    $nama = Get-Cell $r 'K'
    if ($null -eq $itemId -or $null -eq $nama) { continue }
    $charms += [ordered]@{
        id = $idCounter++
        no = To-Int (Get-Cell $r 'I')
        item_id = $itemId
        nama_item = $nama
        rarity = To-Int (Get-Cell $r 'L')
        stats = Get-Cell $r 'N'
        image_path = $null
    }
}

# 5. Monsters: Large Monsters (Rows 4..18) + Small Monsters (Rows 26..28), Cols Q..Z
$monsters = @()
$idCounter = 1
for ($r = 4; $r -le 18; $r++) {
    $no = To-Int (Get-Cell $r 'Q')
    $nama = Get-Cell $r 'R'
    if ($null -eq $no -or $null -eq $nama) { continue }
    $imun = Get-Cell $r 'V'
    if ($imun -eq 'None' -or $imun -eq 'none') { $imun = 'None' }
    $drop = Get-Cell $r 'W'
    if ($null -ne $drop) {
        $drop = (($drop -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join ', '
    }
    $monsters += [ordered]@{
        id = $idCounter++
        no = $no
        nama = $nama
        title = Get-Cell $r 'S'
        habitat = Get-Cell $r 'T'
        classification = Get-Cell $r 'U'
        imun_to = $imun
        item_drop = $drop
        max_health = Get-Cell $r 'X'
        def = Get-Cell $r 'Y'
        size = Get-Cell $r 'Z'
        image_path = $null
    }
}
for ($r = 26; $r -le 28; $r++) {
    $noOrig = To-Int (Get-Cell $r 'Q')
    $nama = Get-Cell $r 'R'
    if ($null -eq $noOrig -or $null -eq $nama) { continue }
    $imun = Get-Cell $r 'V'
    if ($imun -eq 'none') { $imun = 'None' }
    elseif ($imun -eq 'burning') { $imun = 'Burning' }
    $drop = Get-Cell $r 'W'
    if ($null -ne $drop) {
        $drop = (($drop -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join ', '
    }
    $monsters += [ordered]@{
        id = $idCounter++
        no = 15 + $noOrig
        nama = $nama
        title = "Small Monster"
        habitat = Get-Cell $r 'T'
        classification = "Small Monster"
        imun_to = $imun
        item_drop = $drop
        max_health = Get-Cell $r 'X'
        def = Get-Cell $r 'Y'
        size = Get-Cell $r 'Z'
        image_path = $null
    }
}

# 6. Animals: Rows 43..44, Cols Q..Z
$animals = @()
$idCounter = 1
for ($r = 43; $r -le 44; $r++) {
    $no = To-Int (Get-Cell $r 'Q')
    $nama = Get-Cell $r 'R'
    if ($null -eq $no -or $null -eq $nama) { continue }
    $animals += [ordered]@{
        id = $idCounter++
        no = $no
        item_id = $null
        nama = $nama
        total_hp = To-Int (Get-Cell $r 'X')
        habitat = Get-Cell $r 'T'
        item_drop = Get-Cell $r 'W'
        image_path = $null
    }
}

$payload = [ordered]@{
    materials = $materials
    armors = $armors
    monsters = $monsters
    weapons = $weapons
    charms = $charms
    animals = $animals
}

$json = $payload | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($jsonOutPath, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Extracted: Materials=$($materials.Count), Armors=$($armors.Count), Weapons=$($weapons.Count), Charms=$($charms.Count), Monsters=$($monsters.Count), Animals=$($animals.Count)"
function Sql-Str($val) {
    if ($null -eq $val -or $val -eq "") { return "NULL" }
    $escaped = $val.ToString().Replace("'", "''")
    return "'$escaped'"
}

function Sql-Num($val) {
    if ($null -eq $val -or $val -eq "") { return "NULL" }
    return [string]$val
}

$sqlLines = @(
    "-- ==========================================================",
    "-- SKRIP SETUP LENGKAP SUPABASE: FRONTIER LANDS DB (RPL)",
    "-- Diekstrak 100% akurat dari Rules Book Frontier Lands.xlsx",
    "-- Jalankan skrip ini di: https://supabase.com/dashboard/project/qqgidnsnnmbvnsvpoifb/sql/new",
    "-- ==========================================================",
    "",
    "-- 1. TABEL MATERIALS",
    "CREATE TABLE IF NOT EXISTS public.materials (",
    "  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,",
    "  `"no`" INTEGER,",
    "  item_id INTEGER,",
    "  nama_item TEXT NOT NULL,",
    "  rarity INTEGER,",
    "  item_type TEXT,",
    "  item_drop TEXT,",
    "  object_drop TEXT,",
    "  persentase REAL,",
    "  image_path TEXT",
    ");",
    "",
    "-- 2. TABEL ARMORS",
    "CREATE TABLE IF NOT EXISTS public.armors (",
    "  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,",
    "  `"no`" INTEGER,",
    "  item_id INTEGER,",
    "  nama_item TEXT NOT NULL,",
    "  rarity INTEGER,",
    "  type TEXT,",
    "  stats TEXT,",
    "  skill TEXT,",
    "  image_path TEXT",
    ");",
    "",
    "-- 3. TABEL MONSTERS",
    "CREATE TABLE IF NOT EXISTS public.monsters (",
    "  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,",
    "  `"no`" INTEGER,",
    "  nama TEXT NOT NULL,",
    "  title TEXT,",
    "  habitat TEXT,",
    "  classification TEXT,",
    "  imun_to TEXT,",
    "  item_drop TEXT,",
    "  max_health TEXT,",
    "  def TEXT,",
    "  size TEXT,",
    "  image_path TEXT",
    ");",
    "",
    "-- 4. TABEL WEAPONS",
    "CREATE TABLE IF NOT EXISTS public.weapons (",
    "  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,",
    "  `"no`" INTEGER,",
    "  item_id INTEGER,",
    "  nama_item TEXT NOT NULL,",
    "  rarity INTEGER,",
    "  role TEXT,",
    "  normal_stats TEXT,",
    "  negative_stats TEXT,",
    "  skill_aktif TEXT,",
    "  image_path TEXT",
    ");",
    "",
    "-- 5. TABEL CHARMS",
    "CREATE TABLE IF NOT EXISTS public.charms (",
    "  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,",
    "  `"no`" INTEGER,",
    "  item_id INTEGER,",
    "  nama_item TEXT NOT NULL,",
    "  rarity INTEGER,",
    "  stats TEXT,",
    "  image_path TEXT",
    ");",
    "",
    "-- 6. TABEL ANIMALS",
    "CREATE TABLE IF NOT EXISTS public.animals (",
    "  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,",
    "  `"no`" INTEGER,",
    "  item_id INTEGER,",
    "  nama TEXT NOT NULL,",
    "  total_hp INTEGER,",
    "  habitat TEXT,",
    "  item_drop TEXT,",
    "  image_path TEXT",
    ");",
    "",
    "-- AKTIFKAN ROW LEVEL SECURITY (RLS)",
    "ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;",
    "ALTER TABLE public.armors ENABLE ROW LEVEL SECURITY;",
    "ALTER TABLE public.monsters ENABLE ROW LEVEL SECURITY;",
    "ALTER TABLE public.weapons ENABLE ROW LEVEL SECURITY;",
    "ALTER TABLE public.charms ENABLE ROW LEVEL SECURITY;",
    "ALTER TABLE public.animals ENABLE ROW LEVEL SECURITY;",
    "",
    "-- BERIKAN AKSES FULL CRUD (BACA, TAMBAH, EDIT, HAPUS) UNTUK APLIKASI",
    "DO `$`$",
    "BEGIN",
    "  DROP POLICY IF EXISTS `"Public Full Access Materials`" ON public.materials;",
    "  CREATE POLICY `"Public Full Access Materials`" ON public.materials FOR ALL USING (true) WITH CHECK (true);",
    "",
    "  DROP POLICY IF EXISTS `"Public Full Access Armors`" ON public.armors;",
    "  CREATE POLICY `"Public Full Access Armors`" ON public.armors FOR ALL USING (true) WITH CHECK (true);",
    "",
    "  DROP POLICY IF EXISTS `"Public Full Access Monsters`" ON public.monsters;",
    "  CREATE POLICY `"Public Full Access Monsters`" ON public.monsters FOR ALL USING (true) WITH CHECK (true);",
    "",
    "  DROP POLICY IF EXISTS `"Public Full Access Weapons`" ON public.weapons;",
    "  CREATE POLICY `"Public Full Access Weapons`" ON public.weapons FOR ALL USING (true) WITH CHECK (true);",
    "",
    "  DROP POLICY IF EXISTS `"Public Full Access Charms`" ON public.charms;",
    "  CREATE POLICY `"Public Full Access Charms`" ON public.charms FOR ALL USING (true) WITH CHECK (true);",
    "",
    "  DROP POLICY IF EXISTS `"Public Full Access Animals`" ON public.animals;",
    "  CREATE POLICY `"Public Full Access Animals`" ON public.animals FOR ALL USING (true) WITH CHECK (true);",
    "END",
    "`$`$;",
    "",
    "-- HAPUS DATA LAMA (JIKA ADA) SEBELUM SEEDING",
    "TRUNCATE TABLE public.materials RESTART IDENTITY CASCADE;",
    "TRUNCATE TABLE public.armors RESTART IDENTITY CASCADE;",
    "TRUNCATE TABLE public.monsters RESTART IDENTITY CASCADE;",
    "TRUNCATE TABLE public.weapons RESTART IDENTITY CASCADE;",
    "TRUNCATE TABLE public.charms RESTART IDENTITY CASCADE;",
    "TRUNCATE TABLE public.animals RESTART IDENTITY CASCADE;",
    "",
    "-- 1. SEED MATERIALS ($($materials.Count) Items)"
)

foreach ($m in $materials) {
    $sqlLines += "INSERT INTO public.materials (`"no`", item_id, nama_item, rarity, item_type, item_drop, object_drop, persentase) VALUES ($(Sql-Num $m.no), $(Sql-Num $m.item_id), $(Sql-Str $m.nama_item), $(Sql-Num $m.rarity), $(Sql-Str $m.item_type), $(Sql-Str $m.item_drop), $(Sql-Str $m.object_drop), $(Sql-Num $m.persentase));"
}

$sqlLines += ""
$sqlLines += "-- 2. SEED ARMORS ($($armors.Count) Items)"
foreach ($a in $armors) {
    $sqlLines += "INSERT INTO public.armors (`"no`", item_id, nama_item, rarity, type, stats, skill) VALUES ($(Sql-Num $a.no), $(Sql-Num $a.item_id), $(Sql-Str $a.nama_item), $(Sql-Num $a.rarity), $(Sql-Str $a.type), $(Sql-Str $a.stats), $(Sql-Str $a.skill));"
}

$sqlLines += ""
$sqlLines += "-- 3. SEED WEAPONS ($($weapons.Count) Items)"
foreach ($w in $weapons) {
    $sqlLines += "INSERT INTO public.weapons (`"no`", item_id, nama_item, rarity, role, normal_stats, negative_stats, skill_aktif) VALUES ($(Sql-Num $w.no), $(Sql-Num $w.item_id), $(Sql-Str $w.nama_item), $(Sql-Num $w.rarity), $(Sql-Str $w.role), $(Sql-Str $w.normal_stats), $(Sql-Str $w.negative_stats), $(Sql-Str $w.skill_aktif));"
}

$sqlLines += ""
$sqlLines += "-- 4. SEED CHARMS ($($charms.Count) Items)"
foreach ($c in $charms) {
    $sqlLines += "INSERT INTO public.charms (`"no`", item_id, nama_item, rarity, stats) VALUES ($(Sql-Num $c.no), $(Sql-Num $c.item_id), $(Sql-Str $c.nama_item), $(Sql-Num $c.rarity), $(Sql-Str $c.stats));"
}

$sqlLines += ""
$sqlLines += "-- 5. SEED MONSTERS ($($monsters.Count) Items)"
foreach ($mo in $monsters) {
    $sqlLines += "INSERT INTO public.monsters (`"no`", nama, title, habitat, classification, imun_to, item_drop, max_health, def, size) VALUES ($(Sql-Num $mo.no), $(Sql-Str $mo.nama), $(Sql-Str $mo.title), $(Sql-Str $mo.habitat), $(Sql-Str $mo.classification), $(Sql-Str $mo.imun_to), $(Sql-Str $mo.item_drop), $(Sql-Str $mo.max_health), $(Sql-Str $mo.def), $(Sql-Str $mo.size));"
}

$sqlLines += ""
$sqlLines += "-- 6. SEED ANIMALS ($($animals.Count) Items)"
foreach ($an in $animals) {
    $sqlLines += "INSERT INTO public.animals (`"no`", item_id, nama, total_hp, habitat, item_drop) VALUES ($(Sql-Num $an.no), $(Sql-Num $an.item_id), $(Sql-Str $an.nama), $(Sql-Num $an.total_hp), $(Sql-Str $an.habitat), $(Sql-Str $an.item_drop));"
}

[System.IO.File]::WriteAllText($sqlOutPath, ($sqlLines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Generated supabase_schema.sql successfully."
