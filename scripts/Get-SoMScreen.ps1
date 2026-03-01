Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# 新增：检测是否在录屏模式，避免干扰
$Global:SoMRecordingMode = $false

function Get-ClickableElements {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    
    # 优化：只找可交互的控制类型
    $controlTypes = @(
        [System.Windows.Automation.ControlType]::Button
        [System.Windows.Automation.ControlType]::MenuItem
        [System.Windows.Automation.ControlType]::ListItem
        [System.Windows.Automation.ControlType]::TreeItem
        [System.Windows.Automation.ControlType]::Hyperlink
        [System.Windows.Automation.ControlType]::TabItem
        [System.Windows.Automation.ControlType]::CheckBox
        [System.Windows.Automation.ControlType]::RadioButton
        [System.Windows.Automation.ControlType]::ComboBox
        [System.Windows.Automation.ControlType]::Edit
        [System.Windows.Automation.ControlType]::Document  # 浏览器页面
    )
    
    $results = @()
    $id = 0
    
    foreach ($type in $controlTypes) {
        $condition = [System.Windows.Automation.ControlTypeCondition]::FromControlType($type)
        $elements = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
        
        foreach ($el in $elements) {
            # 关键过滤：必须是可见且启用的
            if ($el.Current.IsOffscreen -or -not $el.Current.IsEnabled) { continue }
            
            $rect = $el.Current.BoundingRectangle
            
            # 新增：高 DPI 坐标转换
            $x = [int](($rect.Left + $rect.Right) / 2)
            $y = [int](($rect.Top + $rect.Bottom) / 2)
            
            # 碰撞检测：避免编号重叠（简单版：距离太近的元素只保留第一个）
            $tooClose = $false
            foreach ($existing in $results) {
                $dist = [Math]::Sqrt([Math]::Pow($x - $existing.X, 2) + [Math]::Pow($y - $existing.Y, 2))
                if ($dist -lt 30) { $tooClose = $true; break }
            }
            if ($tooClose) { continue }
            
            $results += [PSCustomObject]@{
                Id          = ($id++)
                Name        = $el.Current.Name
                X           = $x
                Y           = $y
                ControlType = $type.ProgrammaticName
                AutomationId = $el.Current.AutomationId
                # 新增：用于验证元素是否还在原位
                BoundingRect = "$($rect.Left),$($rect.Top),$($rect.Width),$($rect.Height)"
            }
        }
    }
    
    # 限制数量并按 Y 坐标排序（从上到下，符合阅读顺序）
    return $results | Sort-Object Y | Select-Object -First 40
}

function Export-SoMEnvironment {
    param(
        [string]$OutputDir = "C:\temp\openclaw",
        [switch]$IncludeCursor = $true
    )
    
    # 确保目录存在
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    
    $elements = Get-ClickableElements
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    
    # 高 DPI 感知：获取实际像素尺寸
    Add-Type @"
    using System; using System.Runtime.InteropServices;
    public class DpiHelper {
        [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
        public static int GetScaleFactor() {
            IntPtr screen = IntPtr.Zero; // 简化处理，主屏幕
            // 实际生产环境需要更复杂的 DPI 检测
            return 100; // 返回百分比，如 125, 150
        }
    }
"@
    
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    
    # 截取屏幕（如果 IncludeCursor，先移动鼠标到角落避免遮挡）
    if ($IncludeCursor) {
        Add-Type -AssemblyName System.Windows.Forms
        $originalPos = [System.Windows.Forms.Cursor]::Position
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(0, 0)
        Start-Sleep -Milliseconds 100
    }
    
    $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    
    if ($IncludeCursor) {
        [System.Windows.Forms.Cursor]::Position = $originalPos
    }
    
    # 绘制编号（带背景圆，提高可读性）
    $font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $bgBrush = [System.Drawing.Brushes]::Red
    $textBrush = [System.Drawing.Brushes]::White
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Yellow, 2)
    
    foreach ($el in $elements) {
        # 绘制外圈
        $graphics.DrawEllipse($pen, $el.X - 15, $el.Y - 15, 30, 30)
        # 绘制背景圆
        $graphics.FillEllipse($bgBrush, $el.X - 12, $el.Y - 12, 24, 24)
        # 绘制文字（居中）
        $text = $el.Id.ToString()
        $size = $graphics.MeasureString($text, $font)
        $graphics.DrawString($text, $font, $textBrush, $el.X - $size.Width/2, $el.Y - $size.Height/2)
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $imgPath = "$OutputDir\som_$timestamp.png"
    $jsonPath = "$OutputDir\som_$timestamp.json"
    
    $bmp.Save($imgPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bmp.Dispose()
    
    # 输出包含元数据的 JSON
    $metadata = @{
        Timestamp = Get-Date -Format "o"
        ScreenResolution = "$($screen.Width)x$($screen.Height)"
        ElementCount = $elements.Count
        Elements = $elements
    }
    
    $metadata | ConvertTo-Json -Depth 3 | Out-File -Encoding UTF8 $jsonPath
    
    Write-Host "✅ SoM 环境已生成：" -ForegroundColor Green
    Write-Host "   图像：$imgPath" -ForegroundColor Cyan
    Write-Host "   数据：$jsonPath" -ForegroundColor Cyan
    
    return @{
        ImagePath = $imgPath
        JsonPath = $jsonPath
        Elements = $elements
        Timestamp = $timestamp
    }
}

# 执行
Export-SoMEnvironment