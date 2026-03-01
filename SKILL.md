description:结合 SoM 视觉标注的 Windows 原生鼠标控制。支持“观察模式”学习用户操作流，并通过“执行模式”利用编号坐标实现像素级精确点击。Win Mouse Native Pro (SoM Integrated)核心流程：观察 -> 建模 -> 执行1. 观察与学习 (Observation Mode)当用户说“我教你怎么做”时：输入：调用 nodes 录屏（1 fps）及用户音频 。处理：识别用户操作的软件环境（如 Excel、浏览器）、操作动作（点击、拖拽）及逻辑先后顺序。输出：生成一个操作流模型（Action Sequence Model）。2. 环境初始化 (Initialization)在准备复刻任务时：调用指令：首先运行 scripts/Get-SoMScreen.ps1。效果：系统会生成一张带有红色编号圆圈的截图 som_screen.png 和对应的坐标映射表 som_map.json。3. 精确执行 (Execution Mode)定位：AI 识别出当前步骤需要点击“确定”按钮，并在 som_screen.png 中找到该按钮对应的编号（例如：12）。映射：从 som_map.json 中读取编号 12 的精确坐标 (x, y)。动作：通过 win-mouse 执行具体物理操作：win-mouse abs <x> <y> (移动到目标点) win-mouse click left (执行点击) 常用指令参考指令用途参数示例win-mouse abs <x> <y>绝对坐标定位 win-mouse abs 1024 768win-mouse move <dx> <dy>相对位置微调 win-mouse move 10 -5win-mouse click模拟完整点击动作 win-mouse click leftwin-mouse down/up用于模拟长按或拖拽 win-mouse down left注意事项任务空间闭环：每执行完一步操作，必须通过重新截图/录屏确认当前“任务空间”的状态变化，直到目标达成。动态修正：若 som_map.json 中的编号位置因窗口移动失效，需重新运行 Get-SoMScreen.ps1 刷新坐标。🚀 你的系统工作原理图示💡 深度建议：如何处理“拖拽”在你的“手把手教学”中，拖拽（比如把文件拉进文件夹）是很常见的。通过更新后的技能，OpenClaw 的逻辑应该是：在 SoM 图中找到“文件”的编号（设为 1）和“文件夹”的编号（设为 2）。调用 win-mouse abs <X1> <Y1> 。调用 win-mouse down left（按住不放）。调用 win-mouse abs <X2> <Y2>（平滑移动到目的地）。调用 win-mouse up left（松开鼠标）。


你正在使用 Windows 原生鼠标控制技能。规则：

1. 启动教学：
   - 调用 StartTeaching
   - 告诉用户："请点击屏幕右上角的红色按钮结束录制"

2. 执行过程中（每 5-10 秒）：
   - 调用 CheckIfUserRequestedStop
   - 如果返回 UserWantsToStop = true：
     → 询问用户："我看到您点击了停止按钮，确认要结束教学吗？"
     → 用户说"是的" → 调用 EndTeaching → 分析录屏
     → 用户说"继续" → （可选：调用指示器的 Resume 功能，或忽略）

3. 自然语言兜底：
   - 如果用户说"我教完了"、"停止吧"、"结束"：
     → 同样询问确认 → 调用 EndTeaching

4. **坐标失效处理**：
   - 如果执行 abs 后实际位置与预期偏差 >10 像素 → 可能是 DPI 问题
   - 立即重新运行 Get-SoMScreen.ps1 刷新坐标

5. **安全边界**：
   - 绝不对编号不明的元素执行操作
   - 绝对坐标必须限制在屏幕范围内（脚本会自动处理）