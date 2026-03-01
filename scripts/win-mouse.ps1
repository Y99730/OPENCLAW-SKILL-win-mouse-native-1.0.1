# 新增：滚轮支持和高 DPI 坐标修正
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class WinMouse {
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT lpPoint);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
    public const int SM_CXSCREEN = 0;
    public const int SM_CYSCREEN = 1;

    // 新增：获取 DPI 缩放
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("gdi32.dll")] public static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
    public const int LOGPIXELSX = 88;

    public static float GetDpiScale() {
        IntPtr hdc = GetDC(IntPtr.Zero);
        int dpi = GetDeviceCaps(hdc, LOGPIXELSX);
        ReleaseDC(IntPtr.Zero, hdc);
        return dpi / 96.0f; // 标准 96 DPI
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT {
        public uint type;
        public MOUSEINPUT mi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    public const uint INPUT_MOUSE = 0;
    public const uint MOUSEEVENTF_MOVE = 0x0001;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    public const uint MOUSEEVENTF_RIGHTUP = 0x0010;
    public const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    public const uint MOUSEEVENTF_MIDDLEUP = 0x0040;
    // 新增：滚轮
    public const uint MOUSEEVENTF_WHEEL = 0x0800;
    public const uint WHEEL_DELTA = 120;

    public static POINT GetPos() {
        POINT p; GetCursorPos(out p); return p;
    }

    public static void Move(int dx, int dy) {
        // 相对移动（使用 MOUSEEVENTF_MOVE，不调用 SetCursorPos）
        var input = new INPUT();
        input.type = INPUT_MOUSE;
        input.mi = new MOUSEINPUT(){ 
            dx = dx, 
            dy = dy, 
            mouseData = 0, 
            dwFlags = MOUSEEVENTF_MOVE, 
            time = 0, 
            dwExtraInfo = IntPtr.Zero 
        };
        SendInput(1, new INPUT[]{ input }, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void Scroll(int delta) {
        var input = new INPUT();
        input.type = INPUT_MOUSE;
        input.mi = new MOUSEINPUT(){ 
            dx = 0, 
            dy = 0, 
            mouseData = (uint)(delta * WHEEL_DELTA), 
            dwFlags = MOUSEEVENTF_WHEEL, 
            time = 0, 
            dwExtraInfo = IntPtr.Zero 
        };
        SendInput(1, new INPUT[]{ input }, Marshal.SizeOf(typeof(INPUT)));
    }

    public static void Button(string btn, string action) {
        uint flag;
        switch(btn.ToLowerInvariant()) {
            case "left":   flag = (action=="down") ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP; break;
            case "right":  flag = (action=="down") ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP; break;
            case "middle": flag = (action=="down") ? MOUSEEVENTF_MIDDLEDOWN : MOUSEEVENTF_MIDDLEUP; break;
            default: throw new ArgumentException("button must be left|right|middle");
        }

        var input = new INPUT();
        input.type = INPUT_MOUSE;
        input.mi = new MOUSEINPUT(){ dx=0, dy=0, mouseData=0, dwFlags=flag, time=0, dwExtraInfo=IntPtr.Zero };

        var sent = SendInput(1, new INPUT[]{ input }, Marshal.SizeOf(typeof(INPUT)));
        if(sent != 1) throw new Exception("SendInput failed: " + Marshal.GetLastWin32Error());
    }

    public static void Click(string btn) {
        Button(btn, "down");
        System.Threading.Thread.Sleep(50); // 人类化延迟
        Button(btn, "up");
    }
    
    public static void DoubleClick(string btn) {
        Click(btn);
        System.Threading.Thread.Sleep(100);
        Click(btn);
    }
}
"@ -Language CSharp

function JsonOut($ok, $cmd, $details) {
    $obj = [ordered]@{ ok = $ok; cmd = $cmd; timestamp = (Get-Date -Format "o") }
    foreach($k in $details.Keys){ $obj[$k] = $details[$k] }
    ($obj | ConvertTo-Json -Compress)
}

# 新增：验证函数，检查元素是否还在预期位置
function Test-ElementPosition {
    param($ExpectedX, $ExpectedY, $Tolerance = 5)
    $pos = [WinMouse]::GetPos()
    $dist = [Math]::Sqrt([Math]::Pow($pos.X - $ExpectedX, 2) + [Math]::Pow($pos.Y - $ExpectedY, 2))
    return $dist -le $Tolerance
}

$Cmd = $args[0]
$A = $args[1]
$B = $args[2]

if(-not $Cmd){
    Write-Output (JsonOut $false $null @{ error = 'usage: win-mouse <move|abs|click|doubleclick|down|up|scroll> ...' })
    exit 2
}

$before = [WinMouse]::GetPos()

try {
    switch($Cmd.ToLowerInvariant()){
'abs' {
    if($null -eq $A -or $null -eq $B){ throw 'usage: win-mouse abs <x> <y>' }
    
    # 仅检测并警告，不转换坐标
    $scale = [WinMouse]::GetDpiScale()
    if ($scale -ne 1.0) {
        Write-Warning "检测到 DPI 缩放 ($scale)，如果点击偏移请调整显示器缩放为100%"
    }
    
    $targetX = [int]$A
    $targetY = [int]$B
    
    $maxWidth = [WinMouse]::GetSystemMetrics([WinMouse]::SM_CXSCREEN)
    $maxHeight = [WinMouse]::GetSystemMetrics([WinMouse]::SM_CYSCREEN)
    
    $x = [Math]::Max(0, [Math]::Min($targetX, $maxWidth - 1))
    $y = [Math]::Max(0, [Math]::Min($targetY, $maxHeight - 1))

    [void][WinMouse]::SetCursorPos($x, $y)
    $after = [WinMouse]::GetPos()
    Write-Output (JsonOut $true 'abs' @{ 
        before = @{ X=$before.X; Y=$before.Y }; 
        after = @{ X=$after.X; Y=$after.Y }; 
        requested = @{ X=$A; Y=$B };
        dpiScale = $scale
    })
}
        'move' {
            if($null -eq $A -or $null -eq $B){ throw 'usage: win-mouse move <dx> <dy>' }
            $dx = [int]$A; $dy = [int]$B
            
            # 使用 SendInput 的相对移动，更平滑
            [WinMouse]::Move($dx, $dy)
            
            Start-Sleep -Milliseconds 50
            $after = [WinMouse]::GetPos()
            Write-Output (JsonOut $true 'move' @{ 
                before=@{ X=$before.X; Y=$before.Y }; 
                after=@{ X=$after.X; Y=$after.Y }; 
                delta=@{ X=$dx; Y=$dy };
                actualDelta=@{ X=($after.X - $before.X); Y=($after.Y - $before.Y) }
            })
        }
        'click' {
            $btn = if($A){$A}else{'left'}
            [WinMouse]::Click($btn)
            $after = [WinMouse]::GetPos()
            Write-Output (JsonOut $true 'click' @{ button=$btn; position=@{ X=$after.X; Y=$after.Y }})
        }
        'doubleclick' {
            $btn = if($A){$A}else{'left'}
            [WinMouse]::DoubleClick($btn)
            $after = [WinMouse]::GetPos()
            Write-Output (JsonOut $true 'doubleclick' @{ button=$btn; position=@{ X=$after.X; Y=$after.Y }})
        }
        'scroll' {
            if($null -eq $A){ throw 'usage: win-mouse scroll <lines> (positive=up, negative=down)' }
            [WinMouse]::Scroll([int]$A)
            Write-Output (JsonOut $true 'scroll' @{ lines=$A; direction=$(if($A -gt 0){"up"}else{"down"})})
        }
        'down' {
            if(-not $A){ throw 'usage: win-mouse down <left|right|middle>' }
            [WinMouse]::Button($A,'down')
            Write-Output (JsonOut $true 'down' @{ button=$A; position=@{ X=$before.X; Y=$before.Y }})
        }
        'up' {
            if(-not $A){ throw 'usage: win-mouse up <left|right|middle>' }
            [WinMouse]::Button($A,'up')
            Write-Output (JsonOut $true 'up' @{ button=$A; position=@{ X=$before.X; Y=$before.Y }})
        }
        default {
            Write-Output (JsonOut $false $Cmd @{ error = 'unknown command' })
            exit 2
        }
    }
} catch {
    Write-Output (JsonOut $false $Cmd @{ error = $_.Exception.Message })
    exit 1
}