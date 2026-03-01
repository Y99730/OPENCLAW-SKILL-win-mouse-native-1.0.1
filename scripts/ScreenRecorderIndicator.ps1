# ScreenRecorderIndicator.ps1
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Start", "Stop", "CheckStatus", "ConfirmStop")]
    [string]$Action,
    [string]$Position = "TopRight"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$IndicatorFile = "$env:TEMP\openclaw_recorder_indicator.json"
$SignalFile = "$env:TEMP\openclaw_stop_request.json"

function Show-RecordingIndicator {
    $form = New-Object System.Windows.Forms.Form
    $form.Width = 160
    $form.Height = 90
    $form.BackColor = [System.Drawing.Color]::FromArgb(220, 50, 50)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    
    # 位置计算...
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location = New-Object System.Drawing.Point(($screen.Width - 170), 10)
    
    # 标题栏
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $titlePanel.Height = 30
    $titlePanel.BackColor = [System.Drawing.Color]::FromArgb(180, 0, 0)
    
    $recLabel = New-Object System.Windows.Forms.Label
    $recLabel.Text = "● REC"
    $recLabel.ForeColor = [System.Drawing.Color]::White
    $recLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $recLabel.Location = New-Object System.Drawing.Point(10, 5)
    $titlePanel.Controls.Add($recLabel)
    
    # 闪烁动画
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 800
    $script:dotVisible = $true
    $timer.Add_Tick({
        $script:dotVisible = -not $script:dotVisible
        $recLabel.Text = if($script:dotVisible) { "● REC" } else { "○ REC" }
    })
    $timer.Start()
    
    # 停止按钮
    $stopButton = New-Object System.Windows.Forms.Button
    $stopButton.Text = "⏹ 停止教学"
    $stopButton.Location = New-Object System.Drawing.Point(10, 40)
    $stopButton.Size = New-Object System.Drawing.Size(140, 35)
    $stopButton.BackColor = [System.Drawing.Color]::White
    $stopButton.ForeColor = [System.Drawing.Color]::FromArgb(200, 0, 0)
    $stopButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $stopButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $stopButton.FlatAppearance.BorderSize = 0
    
    # 关键：点击后进入"等待确认"状态，不关闭窗口
    $stopButton.Add_Click({
        # 写入信号文件（带时间戳）
        @{
            Status = "StopRequested"
            Timestamp = Get-Date -Format "o"
            Message = "用户请求停止教学，等待AI确认"
        } | ConvertTo-Json | Out-File $SignalFile -Force
        
        # 视觉反馈：变橙/黄，显示等待中
        $form.BackColor = [System.Drawing.Color]::FromArgb(255, 165, 0) # 橙色
        $stopButton.Text = "⏳ 等待确认..."
        $stopButton.Enabled = $false
        $stopButton.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
        
        # 停止闪烁，显示静态图标
        $timer.Stop()
        $recLabel.Text = "⏸ PAUSED"
    })
    
    # 允许拖动
    $titlePanel.Add_MouseDown({
        $form.Capture = $false
        $msg = [System.Windows.Forms.Message]::Create($form.Handle, 0xA1, 0x2, 0)
        [void]$form.DefWndProc($msg)
    })
    
    $form.Controls.Add($stopButton)
    $form.Controls.Add($titlePanel)
    
    # 保存进程信息
    @{
        ProcessId = $PID
        StartTime = Get-Date -Format "o"
        WindowHandle = $form.Handle.ToInt64()
    } | ConvertTo-Json | Out-File $IndicatorFile -Force
    
    [void]$form.ShowDialog()
}

function Stop-Indicator {
    if (Test-Path $IndicatorFile) {
        $info = Get-Content $IndicatorFile | ConvertFrom-Json
        Stop-Process -Id $info.ProcessId -Force -ErrorAction SilentlyContinue
        Remove-Item $IndicatorFile -Force
        Remove-Item $SignalFile -Force -ErrorAction SilentlyContinue
    }
}

function Get-Status {
    if (Test-Path $SignalFile) {
        $signal = Get-Content $SignalFile | ConvertFrom-Json
        return @{ 
            HasSignal = $true
            Signal = $signal
            # 不删除文件，等待 ConfirmStop 再删
        }
    }
    return @{ HasSignal = $false }
}

function Confirm-Stop {
    # 大模型确认后调用，真正关闭指示器
    Stop-Indicator
    return @{ Confirmed = $true }
}

switch ($Action) {
    "Start" { Show-RecordingIndicator }
    "Stop" { Stop-Indicator }
    "CheckStatus" { Write-Output (Get-Status | ConvertTo-Json -Compress) }
    "ConfirmStop" { Write-Output (Confirm-Stop | ConvertTo-Json -Compress) }
}