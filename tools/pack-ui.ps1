# Packs the SpriteCook UI-kit parts (art/ui/kit/parts) into Roblox-sized
# atlases (art/ui/kit/atlas-*.png, at most 1024x1024) and writes where each
# part sits, plus its 9-slice borders, into src/shared/UiArtParts.luau.
# Run it after changing a part, then upload both atlases again (README).
param([string]$Root = (Split-Path $PSScriptRoot -Parent))

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class UiPack {
    // Clears opaque pixels that are not part of the biggest opaque blob, so
    // bits of neighbouring parts caught in a crop go away.
    public static void KeepLargest(Bitmap bmp, int threshold) {
        int w = bmp.Width, h = bmp.Height;
        var rect = new Rectangle(0, 0, w, h);
        var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = data.Stride;
        byte[] px = new byte[stride * h];
        Marshal.Copy(data.Scan0, px, 0, px.Length);
        int[] label = new int[w * h];
        var sizes = new List<int>(); sizes.Add(0);
        var stack = new Stack<int>();
        int next = 0;
        for (int i = 0; i < w * h; i++) {
            if (label[i] != 0 || px[(i / w) * stride + (i % w) * 4 + 3] < threshold) continue;
            next++; int count = 0;
            label[i] = next; stack.Push(i);
            while (stack.Count > 0) {
                int p = stack.Pop(); count++;
                int x = p % w, y = p / w;
                for (int d = 0; d < 4; d++) {
                    int nx = x + (d == 0 ? 1 : d == 1 ? -1 : 0), ny = y + (d == 2 ? 1 : d == 3 ? -1 : 0);
                    if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                    int q = ny * w + nx;
                    if (label[q] != 0 || px[ny * stride + nx * 4 + 3] < threshold) continue;
                    label[q] = next; stack.Push(q);
                }
            }
            sizes.Add(count);
        }
        int best = 1;
        for (int k = 1; k < sizes.Count; k++) if (sizes[k] > sizes[best]) best = k;
        int cleared = 0;
        for (int i = 0; i < w * h; i++) {
            if (label[i] != 0 && label[i] != best) {
                int o = (i / w) * stride + (i % w) * 4;
                px[o] = px[o + 1] = px[o + 2] = px[o + 3] = 0; cleared++;
            }
        }
        Marshal.Copy(px, 0, data.Scan0, px.Length);
        bmp.UnlockBits(data);
        Console.WriteLine("  cleared " + cleared + " stray pixels");
    }

    public static Bitmap Scale(Bitmap src, int w, int h) {
        var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(dst)) {
            g.CompositingMode = CompositingMode.SourceCopy;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.SmoothingMode = SmoothingMode.HighQuality;
            using (var attrs = new ImageAttributes()) {
                attrs.SetWrapMode(WrapMode.TileFlipXY);
                g.DrawImage(src, new Rectangle(0, 0, w, h), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel, attrs);
            }
        }
        return dst;
    }
}
"@

$parts = "$Root\art\ui\kit\parts"
# name, atlas, scale, 9-slice borders in source pixels (left, top, right, bottom) or $null,
# and $true to keep every bit of it (icons with loose sparkles or pearls)
$specs = @(
    @("window", "panels", 0.56, @(440, 190, 160, 80)),
    @("ribbon", "panels", 0.5, $null),
    @("close", "panels", 0.5, $null),
    @("button_pink", "panels", 0.5, @(70, 62, 70, 62)),
    @("button_mint", "panels", 0.5, @(70, 62, 70, 62)),
    @("button_lemon", "panels", 0.5, @(70, 62, 70, 62)),
    @("button_white", "panels", 0.5, @(70, 62, 70, 62)),
    @("button_sky", "panels", 0.5, @(70, 66, 70, 66)),
    @("button_grey", "panels", 0.5, @(70, 64, 70, 64)),
    @("minus", "panels", 0.5, $null),
    @("plus", "panels", 0.5, $null),
    @("toggle_on", "panels", 0.5, $null),
    @("toggle_off", "panels", 0.5, $null),
    @("coin_counter", "panels", 0.22, @(420, 220, 345, 220)),
    @("plus_mint", "panels", 0.5, $null),
    @("coin", "panels", 0.085, $null),
    @("tile", "panels", 0.45, @(70, 70, 70, 70)),
    @("well", "panels", 0.35, $null),
    @("dock_shop", "icons", 0.6, $null),
    @("dock_bag", "icons", 0.6, $null),
    @("dock_stats", "icons", 0.6, $null),
    @("dock_settings", "icons", 0.6, $null),
    @("dock_invite", "icons", 0.6, $null),
    @("stat_trophy", "icons", 0.55, $null),
    @("stat_stopwatch", "icons", 0.55, $null),
    @("stat_footprints", "icons", 0.55, $null),
    @("stat_skull", "icons", 0.55, $null),
    @("stat_shell", "icons", 0.55, $null),
    @("stat_wave", "icons", 0.55, $null),
    @("action_pebble", "icons", 0.8, $null),
    @("action_updraft", "icons", 0.8, $null),
    @("action_hush", "icons", 0.8, $null),
    @("robux_coins_small", "icons", 0.6, $null, $true),
    @("robux_coins_jar", "icons", 0.6, $null, $true),
    @("robux_coins_chest", "icons", 0.6, $null, $true),
    @("robux_coins_hoard", "icons", 0.6, $null, $true),
    @("robux_self_revive", "icons", 0.6, $null, $true),
    @("robux_double_coins", "icons", 0.6, $null, $true),
    @("robux_pockets", "icons", 0.6, $null, $true),
    @("robux_kit", "icons", 0.6, $null, $true),
    @("sunburst", "icons", 0.5, $null, $true),
    @("sparkle", "icons", 0.2, $null, $true)
)

$MAX = 1024
$PAD = 4
$placed = @{}
$lines = New-Object System.Collections.Generic.List[string]

foreach ($atlasName in @("panels", "icons")) {
    $items = @()
    foreach ($s in $specs) {
        if ($s[1] -ne $atlasName) { continue }
        $src = [System.Drawing.Bitmap]::FromFile("$parts\$($s[0]).png")
        $copy = New-Object System.Drawing.Bitmap($src)
        $src.Dispose()
        Write-Host $s[0]
        if (-not $s[4]) { [UiPack]::KeepLargest($copy, 24) }
        $w = [int][math]::Round($copy.Width * $s[2]); $h = [int][math]::Round($copy.Height * $s[2])
        $scaled = [UiPack]::Scale($copy, $w, $h)
        $copy.Dispose()
        $items += ,@($s[0], $scaled, $s[2], $s[3])
    }
    # Shelf packing, tallest first.
    $items = $items | Sort-Object { $_[1].Height } -Descending
    $x = 0; $y = 0; $shelf = 0
    $spots = @()
    foreach ($it in $items) {
        $bmp = $it[1]
        if ($x + $bmp.Width -gt $MAX) { $x = 0; $y += $shelf + $PAD; $shelf = 0 }
        $spots += ,@($it, $x, $y)
        $x += $bmp.Width + $PAD
        if ($bmp.Height -gt $shelf) { $shelf = $bmp.Height }
    }
    $height = $y + $shelf
    if ($height -gt $MAX) { throw "$atlasName atlas is $height tall, over $MAX" }
    $atlas = New-Object System.Drawing.Bitmap($MAX, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($atlas)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.Clear([System.Drawing.Color]::Transparent)
    foreach ($spot in $spots) {
        $it = $spot[0]; $bmp = $it[1]
        $g.DrawImageUnscaled($bmp, $spot[1], $spot[2])
        $slice = "nil"
        if ($it[3]) {
            $b = $it[3] | ForEach-Object { [int][math]::Round($_ * $it[2]) }
            $slice = "{ $($b[0]), $($b[1]), $($b[2]), $($b[3]) }"
        }
        $placed[$it[0]] = "`t$($it[0]) = { atlas = `"$atlasName`", x = $($spot[1]), y = $($spot[2]), w = $($bmp.Width), h = $($bmp.Height), slice = $slice },"
        $bmp.Dispose()
    }
    $g.Dispose()
    $out = "$Root\art\ui\kit\atlas-$atlasName.png"
    $atlas.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $atlas.Dispose()
    Write-Host "$atlasName -> $MAX x $height"
}

foreach ($s in $specs) { $lines.Add($placed[$s[0]]) }
$header = @"
-- Generated by tools/pack-ui.ps1 from the SpriteCook UI kit "Still Water lobby
-- menus" (art/ui/kit/parts, logged in art/spritecook-assets.json): where each
-- part sits in its atlas (art/ui/kit/atlas-<name>.png), in pixels, and its
-- 9-slice borders (left, top, right, bottom) for parts that stretch.
-- Don't edit by hand; repack instead. The atlases' Roblox ids live in UiArt.luau.

return {
"@
$luau = $header + "`n" + ($lines -join "`n") + "`n}`n"
[System.IO.File]::WriteAllText("$Root\src\shared\UiArtParts.luau", $luau.Replace("`r`n", "`n"))
Write-Host "wrote UiArtParts.luau"
