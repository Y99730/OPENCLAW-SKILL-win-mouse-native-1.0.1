# OPENCLAW-SKILL-win-mouse-native-1.0.1
Enable your Openclaw to control the mouse and learn your operations through video recording, then mechanically execute the operations you need
通过`nodes` 录屏1帧/秒，以及用户的声音教学。返回给大模型，让大模型知道用户在做什么（在什么软件\页面进行了什么操作），大模型通过视频，形成一个有关的操作流。如果大模型无法识别是什么软件或者什么页面或者什么操作，中断并且询问用户，理解用户的信息并且记录在操作流中。给openclaw发出命令之后，如果正在录屏，会有录屏提示。
用户给大模型布置任务，确认任务空间。
大模型通过控制鼠标，以及Set-of-Mark网格，精确的定位每个按键的位置，通过坐标控制鼠标移动到相应位置，进行机械的操作。
直到将任务空间全部转换为完成的任务空间。


Record 1 frame/second of screen through 'nodes' and provide user voice teaching. Return to the big model to let it know what the user is doing (what software/page they are operating on), and the big model forms a relevant operation flow through video. If the large model cannot recognize what software, page, or operation it is, interrupt and ask the user, understand the user's information, and record it in the operation flow. After issuing the command to openclaw, if recording is in progress, there will be a screen recording prompt.
Users assign tasks to the large model and confirm the task space.
The large model precisely locates the position of each button by controlling the mouse and the Set of Mark grid, and moves the mouse to the corresponding position through coordinate control to perform mechanical operations.
Until all task spaces are converted into completed task spaces.
