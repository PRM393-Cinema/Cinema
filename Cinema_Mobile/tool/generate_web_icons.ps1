# Render the vector mark with Windows' built-in drawing library; no packages.
Add-Type -AssemblyName System.Drawing
$webRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../web'))
foreach ($maskable in @($false, $true)) {
    $bitmap = [Drawing.Bitmap]::new(1024, 1024)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.ScaleTransform(16, 16)
    $background = [Drawing.Drawing2D.LinearGradientBrush]::new(
        [Drawing.Point]::new(0, 0), [Drawing.Point]::new(64, 64),
        [Drawing.ColorTranslator]::FromHtml('#172231'), [Drawing.ColorTranslator]::FromHtml('#0B0D12'))
    $shape = [Drawing.Drawing2D.GraphicsPath]::new()
    if ($maskable) {
        $graphics.FillRectangle($background, 0, 0, 64, 64)
        $graphics.TranslateTransform(6.4, 6.4)
        $graphics.ScaleTransform(0.8, 0.8)
    } else {
        foreach ($arc in @(@(0, 0, 180), @(36, 0, 270), @(36, 36, 0), @(0, 36, 90))) {
            $shape.AddArc($arc[0], $arc[1], 28, 28, $arc[2], 90)
        }
        $shape.CloseFigure()
        $graphics.FillPath($background, $shape)
    }
    $cyan = [Drawing.Drawing2D.LinearGradientBrush]::new(
        [Drawing.Point]::new(13, 11), [Drawing.Point]::new(49, 47),
        [Drawing.ColorTranslator]::FromHtml('#00E5EC'), [Drawing.ColorTranslator]::FromHtml('#009BD8'))
    $ring = [Drawing.Pen]::new($cyan, 6)
    $graphics.DrawEllipse($ring, 13, 11, 36, 36)
    $tail = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#00C9E4'), 7)
    $tail.StartCap = $tail.EndCap = [Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($tail, 42, 41, 52, 52)
    $play = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#F5FAFF'))
    $graphics.FillPolygon($play, [Drawing.PointF[]]@(
        [Drawing.PointF]::new(27, 21), [Drawing.PointF]::new(27, 37), [Drawing.PointF]::new(40, 29)))
    $sizes = if ($maskable) { @(192, 512) } else { @(32, 192, 512) }
    foreach ($size in $sizes) {
        $output = [Drawing.Bitmap]::new($size, $size)
        $resizer = [Drawing.Graphics]::FromImage($output)
        if ($maskable) { $resizer.Clear([Drawing.ColorTranslator]::FromHtml('#0B0D12')) }
        $resizer.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $resizer.DrawImage($bitmap, 0, 0, $size, $size)
        if ($maskable -and $output.GetPixel(0, 0).A -ne 255) { throw 'Maskable background must be opaque.' }
        $name = if ($size -eq 32) { 'favicon.png' } elseif ($maskable) { "icons/Icon-maskable-$size.png" } else { "icons/Icon-$size.png" }
        $output.Save((Join-Path $webRoot $name), [Drawing.Imaging.ImageFormat]::Png)
        $resizer.Dispose()
        $output.Dispose()
    }
    $graphics.Dispose()
    $bitmap.Dispose()
    $background.Dispose()
    $cyan.Dispose()
    $ring.Dispose()
    $tail.Dispose()
    $play.Dispose()
    $shape.Dispose()
}
