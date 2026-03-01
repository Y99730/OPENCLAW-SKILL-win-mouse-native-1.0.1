param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("StartTeaching", "EndTeaching", "CheckIfUserRequestedStop")]
    [string]$Action
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$IndicatorPath = Join-Path $ScriptDir "ScreenRecorderIndicator.ps1"
$StateFile = "$env:TEMP\openclaw_state.json"

switch ($Action) {
    'StartTeaching' {
        # 启动指示器（后台独立进程）
        Start-Process powershell -ArgumentList `
            "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$IndicatorPath`" -Action Start" `
            -NoNewWindow
        
        @{ Mode = 'Teaching'; StartTime = Get-Date -Format "o" } | 
            ConvertTo-Json | Out-File $StateFile
        
        return @{ 
            Status = "Recording"
            RecordScreen = $true
            FPS = 1
            IncludeAudio = $true
            Note = "用户可点击屏幕右上角红色按钮请求停止"
        }
    }
    
    'CheckIfUserRequestedStop' {
        # OpenClaw 简单检查信号文件是否存在
        $result = & $IndicatorPath -Action CheckStatus | ConvertFrom-Json
        
        if ($result.HasSignal) {
            return @{
                UserWantsToStop = $true
                RequestTime = $result.Signal.Timestamp
                Message = "用户点击了停止按钮，等待确认"
            }
        }
        return @{ UserWantsToStop = $false }
    }
    
    'EndTeaching' {
        # 大模型确认用户要结束后调用
        & $IndicatorPath -Action ConfirmStop
        
        $state = @{ Mode = 'TeachingEnded'; EndTime = Get-Date -Format "o" }
        $state | ConvertTo-Json | Out-File $StateFile
        
        return @{
            Status = "Ended"
            AnalysisRequired = $true
            RecordingPath = "path/to/recording"
        }
    }
}