$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function New-RoundedRectPath {
    param(
        [System.Drawing.RectangleF]$Rect,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-IconBitmap {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $outer = [System.Drawing.RectangleF]::new($Size * 0.06, $Size * 0.06, $Size * 0.88, $Size * 0.88)
    $bgPath = New-RoundedRectPath -Rect $outer -Radius ($Size * 0.2)
    $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $outer,
        [System.Drawing.ColorTranslator]::FromHtml('#0B3C49'),
        [System.Drawing.ColorTranslator]::FromHtml('#3AC47D'),
        55.0
    )
    $g.FillPath($gradient, $bgPath)

    $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 255, 255, 255), ($Size * 0.07))
    $ringRect = [System.Drawing.RectangleF]::new($Size * 0.2, $Size * 0.18, $Size * 0.6, $Size * 0.6)
    $g.DrawArc($ringPen, $ringRect, 205, 295)

    $dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#FFB347'))
    $dotSize = $Size * 0.1
    $g.FillEllipse($dotBrush, $Size * 0.68, $Size * 0.22, $dotSize, $dotSize)

    $fontSize = [math]::Round($Size * 0.27)
    $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(248, 255, 255, 255))
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $textRect = [System.Drawing.RectangleF]::new($Size * 0.1, $Size * 0.18, $Size * 0.8, $Size * 0.58)
    $g.DrawString('CF', $font, $textBrush, $textRect, $format)

    $leafBrush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#D8FFE7'))
    $leafPoints = @(
        [System.Drawing.PointF]::new($Size * 0.48, $Size * 0.76),
        [System.Drawing.PointF]::new($Size * 0.62, $Size * 0.62),
        [System.Drawing.PointF]::new($Size * 0.68, $Size * 0.78),
        [System.Drawing.PointF]::new($Size * 0.54, $Size * 0.86)
    )
    $g.FillPolygon($leafBrush, $leafPoints)

    $stemPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#0B3C49'), ($Size * 0.025))
    $g.DrawLine($stemPen, $Size * 0.54, $Size * 0.84, $Size * 0.63, $Size * 0.7)

    $stemPen.Dispose()
    $leafBrush.Dispose()
    $format.Dispose()
    $textBrush.Dispose()
    $font.Dispose()
    $dotBrush.Dispose()
    $ringPen.Dispose()
    $gradient.Dispose()
    $bgPath.Dispose()
    $g.Dispose()

    return $bmp
}

function New-LogoBitmap {
    param(
        [int]$Width,
        [int]$Height
    )

    $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $iconSize = [int]($Height * 0.82)
    $icon = New-IconBitmap -Size $iconSize
    $g.DrawImage($icon, [int]($Height * 0.06), [int]($Height * 0.09), $iconSize, $iconSize)
    $icon.Dispose()

    $textX = [int]($Height * 1.02)
    $font = New-Object System.Drawing.Font('Segoe UI Semibold', [math]::Round($Height * 0.3), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brushPrimary = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#0B3C49'))
    $brushAccent = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#2FAE66'))
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Near
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $y = $Height * 0.5
    $g.DrawString('Calorie', $font, $brushPrimary, [System.Drawing.PointF]::new($textX, $y - ($Height * 0.04)), $format)
    $prefixWidth = $g.MeasureString('Calorie', $font).Width
    $g.DrawString('Fit', $font, $brushAccent, [System.Drawing.PointF]::new($textX + $prefixWidth - 6, $y - ($Height * 0.04)), $format)

    $brushAccent.Dispose()
    $brushPrimary.Dispose()
    $format.Dispose()
    $font.Dispose()
    $g.Dispose()

    return $bmp
}

function New-SplashBitmap {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $iconSize = [int]($Size * 0.6)
    $icon = New-IconBitmap -Size $iconSize
    $offset = [int](($Size - $iconSize) / 2)
    $g.DrawImage($icon, $offset, $offset, $iconSize, $iconSize)
    $icon.Dispose()
    $g.Dispose()

    return $bmp
}

function Save-Png {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )

    Ensure-Directory (Split-Path -Parent $Path)
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Save-ResizedPng {
    param(
        [System.Drawing.Image]$Source,
        [int]$Width,
        [int]$Height,
        [string]$Path
    )

    $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($Source, 0, 0, $Width, $Height)
    Save-Png -Bitmap $bmp -Path $Path
    $g.Dispose()
    $bmp.Dispose()
}

function Save-IcoFromPng {
    param(
        [string]$PngPath,
        [string]$IcoPath
    )

    $pngBytes = [System.IO.File]::ReadAllBytes($PngPath)
    $stream = [System.IO.File]::Open($IcoPath, [System.IO.FileMode]::Create)
    $writer = New-Object System.IO.BinaryWriter($stream)

    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]1)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]32)
    $writer.Write([UInt32]$pngBytes.Length)
    $writer.Write([UInt32]22)
    $writer.Write($pngBytes)

    $writer.Dispose()
    $stream.Dispose()
}

$brandingDir = Join-Path $root 'assets\branding'
Ensure-Directory $brandingDir

$icon1024 = New-IconBitmap -Size 1024
$mark512 = New-IconBitmap -Size 512
$logoWide = New-LogoBitmap -Width 1200 -Height 320
$splash540 = New-SplashBitmap -Size 540

Save-Png $icon1024 (Join-Path $brandingDir 'caloriefit_icon_source.png')
Save-Png $mark512 (Join-Path $brandingDir 'caloriefit_mark.png')
Save-Png $logoWide (Join-Path $brandingDir 'caloriefit_logo.png')
Save-Png $splash540 (Join-Path $brandingDir 'caloriefit_splash.png')

$androidIconMap = @{
    'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
    'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
    'web\icons\Icon-192.png' = 192
    'web\icons\Icon-maskable-192.png' = 192
    'web\icons\Icon-512.png' = 512
    'web\icons\Icon-maskable-512.png' = 512
    'web\favicon.png' = 64
}

foreach ($relativePath in $androidIconMap.Keys) {
    $size = $androidIconMap[$relativePath]
    Save-ResizedPng -Source $icon1024 -Width $size -Height $size -Path (Join-Path $root $relativePath)
}

$launchLogoPath = Join-Path $root 'android\app\src\main\res\drawable-nodpi\launch_logo.png'
Save-ResizedPng -Source $splash540 -Width 540 -Height 540 -Path $launchLogoPath

$iosIcons = @(
    @{ File = 'Icon-App-20x20@1x.png'; Size = 20 },
    @{ File = 'Icon-App-20x20@2x.png'; Size = 40 },
    @{ File = 'Icon-App-20x20@3x.png'; Size = 60 },
    @{ File = 'Icon-App-29x29@1x.png'; Size = 29 },
    @{ File = 'Icon-App-29x29@2x.png'; Size = 58 },
    @{ File = 'Icon-App-29x29@3x.png'; Size = 87 },
    @{ File = 'Icon-App-40x40@1x.png'; Size = 40 },
    @{ File = 'Icon-App-40x40@2x.png'; Size = 80 },
    @{ File = 'Icon-App-40x40@3x.png'; Size = 120 },
    @{ File = 'Icon-App-60x60@2x.png'; Size = 120 },
    @{ File = 'Icon-App-60x60@3x.png'; Size = 180 },
    @{ File = 'Icon-App-76x76@1x.png'; Size = 76 },
    @{ File = 'Icon-App-76x76@2x.png'; Size = 152 },
    @{ File = 'Icon-App-83.5x83.5@2x.png'; Size = 167 },
    @{ File = 'Icon-App-1024x1024@1x.png'; Size = 1024 }
)

$iosIconDir = Join-Path $root 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
foreach ($item in $iosIcons) {
    Save-ResizedPng -Source $icon1024 -Width $item.Size -Height $item.Size -Path (Join-Path $iosIconDir $item.File)
}

$macIcons = @(
    @{ File = 'app_icon_16.png'; Size = 16 },
    @{ File = 'app_icon_32.png'; Size = 32 },
    @{ File = 'app_icon_64.png'; Size = 64 },
    @{ File = 'app_icon_128.png'; Size = 128 },
    @{ File = 'app_icon_256.png'; Size = 256 },
    @{ File = 'app_icon_512.png'; Size = 512 },
    @{ File = 'app_icon_1024.png'; Size = 1024 }
)

$macIconDir = Join-Path $root 'macos\Runner\Assets.xcassets\AppIcon.appiconset'
foreach ($item in $macIcons) {
    Save-ResizedPng -Source $icon1024 -Width $item.Size -Height $item.Size -Path (Join-Path $macIconDir $item.File)
}

$launchDir = Join-Path $root 'ios\Runner\Assets.xcassets\LaunchImage.imageset'
Save-ResizedPng -Source $splash540 -Width 180 -Height 180 -Path (Join-Path $launchDir 'LaunchImage.png')
Save-ResizedPng -Source $splash540 -Width 360 -Height 360 -Path (Join-Path $launchDir 'LaunchImage@2x.png')
Save-ResizedPng -Source $splash540 -Width 540 -Height 540 -Path (Join-Path $launchDir 'LaunchImage@3x.png')

$winPngPath = Join-Path $brandingDir 'caloriefit_windows_icon.png'
Save-ResizedPng -Source $icon1024 -Width 256 -Height 256 -Path $winPngPath
Save-IcoFromPng -PngPath $winPngPath -IcoPath (Join-Path $root 'windows\runner\resources\app_icon.ico')

$icon1024.Dispose()
$mark512.Dispose()
$logoWide.Dispose()
$splash540.Dispose()

Write-Host 'Generated CalorieFit branding assets.'
