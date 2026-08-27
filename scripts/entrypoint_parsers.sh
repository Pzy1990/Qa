#!/bin/bash

DIR="/workspace/QAnything/logs/debug_logs"
mkdir -p "$DIR"

# 创建模型软连接（模型在镜像 /root/models 内）
# Windows 宿主机挂载的 0 字节占位文件会覆盖镜像内目录，需先 rm -f 再 ln -s
if [ ! -L "/workspace/QAnything/qanything_kernel/dependent_server/ocr_server/ocr_models" ]; then
  rm -f "/workspace/QAnything/qanything_kernel/dependent_server/ocr_server/ocr_models"
  cd /workspace/QAnything/qanything_kernel/dependent_server/ocr_server && ln -s /root/models/ocr_models .
fi

if [ ! -L "/workspace/QAnything/qanything_kernel/dependent_server/pdf_parser_server/pdf_to_markdown/checkpoints" ]; then
  rm -f "/workspace/QAnything/qanything_kernel/dependent_server/pdf_parser_server/pdf_to_markdown/checkpoints"
  cd /workspace/QAnything/qanything_kernel/dependent_server/pdf_parser_server/pdf_to_markdown/ && ln -s /root/models/pdf_models checkpoints
fi

if [ ! -L "/workspace/QAnything/nltk_data" ]; then
  rm -f "/workspace/QAnything/nltk_data"
  cd /workspace/QAnything/ && ln -s /root/nltk_data .
fi

# 修复 Windows 挂载空文件覆盖镜像内模型目录的问题
for dir_pair in \
  "embedding_server/embedding_model_configs_v0.0.1:embedding_model_configs_v0.0.1" \
  "rerank_server/rerank_model_configs_v0.0.1:rerank_model_configs_v0.0.1"
do
  SERVER_DIR="${dir_pair%%:*}"
  MODEL_DIR="${dir_pair##*:}"
  TARGET="/workspace/QAnything/qanything_kernel/dependent_server/${SERVER_DIR}"
  if [ ! -d "$TARGET" ]; then
    rm -f "$TARGET"
    ln -s "/root/models/linux_onnx/${MODEL_DIR}" "$TARGET"
  fi
done

cd /workspace/QAnything || exit

nohup python3 -u qanything_kernel/dependent_server/pdf_parser_server/pdf_parser_server.py > /workspace/QAnything/logs/debug_logs/pdf_parser_server.log 2>&1 &
PID1=$!
nohup python3 -u qanything_kernel/dependent_server/ocr_server/ocr_server.py > /workspace/QAnything/logs/debug_logs/ocr_server.log 2>&1 &
PID2=$!

echo "kill $PID1 $PID2" > close_parsers.sh
chmod +x close_parsers.sh

# 等待两个服务就绪 (Sanic 输出 "Goin' Fast" 表示启动成功)
while ! (grep -qE "Starting worker|Goin' Fast" /workspace/QAnything/logs/debug_logs/pdf_parser_server.log 2>/dev/null && grep -qE "Starting worker|Goin' Fast" /workspace/QAnything/logs/debug_logs/ocr_server.log 2>/dev/null); do
  sleep 1
done

echo "pdf_parser 与 ocr 服务已就绪"

while true; do sleep 5; done