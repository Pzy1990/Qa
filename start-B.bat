@echo off
chcp 65001 >nul
REM ============================================
REM  机器 B 一键启动脚本 —— 存储层
REM  运行: ES + Milvus + etcd + minio + MySQL
REM  请在内存 >=8G 的机器上运行（推荐 >=16G）
REM ============================================

echo [1/3] 检查 Docker Desktop 是否运行...
docker info >nul 2>&1
if errorlevel 1 (
    echo [错误] Docker Desktop 未运行，请先启动 Docker Desktop 后重试。
    pause
    exit /b 1
)

echo [2/3] 拉取并启动存储层容器...
docker compose -f docker-compose-B.yaml up -d
if errorlevel 1 (
    echo [错误] 启动失败，请检查上方报错信息。
    pause
    exit /b 1
)

echo [3/3] 存储层已启动，等待 Milvus 就绪（约 90 秒）...
echo.
echo 存储层服务端口映射（机器 A 将通过这些端口访问）:
echo   ES      (全文检索) : 9210
echo   Milvus  (向量库)   : 19540
echo   MySQL   (元数据)   : 3316
echo.
echo 提示: 若机器 A 无法连接，请在本机 Windows 防火墙放行以上三个端口
echo (以管理员身份运行): netsh advfirewall firewall add rule name="QAnything-B" dir=in action=allow protocol=TCP localport=9210,19540,3316
echo.
pause