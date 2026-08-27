@echo off
chcp 65001 >nul
REM ============================================
REM  机器 A 一键启动脚本 —— 模型层（本机）
REM  运行: qanything 主容器（embedding + rerank + pdf解析 + ocr + 主服务）
REM  存储层部署在机器 B，通过局域网访问（默认 192.168.110.169）
REM ============================================

set STORAGE_IP=192.168.110.169
set /p STORAGE_IP=请输入机器 B 的 IP 地址（回车使用默认 %STORAGE_IP%）: 

echo [1/3] 检查 Docker Desktop 是否运行...
docker info >nul 2>&1
if errorlevel 1 (
    echo [错误] Docker Desktop 未运行，请先启动 Docker Desktop 后重试。
    pause
    exit /b 1
)

echo [2/3] 检查能否访问机器 B 的存储层（MySQL 3316）...
powershell -NoProfile -Command "if (Test-NetConnection -ComputerName %STORAGE_IP% -Port 3316 -InformationLevel Quiet -WarningAction SilentlyContinue) { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo [警告] 无法连接到 %STORAGE_IP%:3316（MySQL），请确认:
    echo   1. 机器 B 已运行 start-B.bat 且容器正常
    echo   2. 机器 B 防火墙已放行 3316/9210/19540 端口
    echo.
    echo 仍要继续启动吗？(Y/N)
    choice /c YN /n
    if errorlevel 2 exit /b 1
)

echo [3/3] 启动模型层容器（首次会拉取镜像，约数 GB）...
docker compose -f docker-compose-A.yaml up -d
if errorlevel 1 (
    echo [错误] 启动失败，请检查上方报错信息。
    pause
    exit /b 1
)

echo.
echo 模型层容器已启动，正在后台加载模型（约 1-2 分钟）...
echo 前端访问地址: http://localhost:8777/qanything/
echo 查看日志: docker logs -f qanything-container-local
echo.
pause