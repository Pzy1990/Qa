import sys
import os

# 获取当前脚本的绝对路径
current_script_path = os.path.abspath(__file__)

# 将项目根目录添加到sys.path
root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(current_script_path))))

sys.path.append(root_dir)
print(root_dir)


from qanything_kernel.utils.general_utils import safe_get
from sanic import Sanic, response
from sanic.request import Request
from sanic.response import json
from qanything_kernel.dependent_server.pdf_parser_server.pdf_parser_backend import PdfLoader
import time
import torch
import argparse
import tempfile
import shutil
import base64

# 接收外部参数mode
parser = argparse.ArgumentParser()
# mode必须是local或online
parser.add_argument('--use_gpu', action="store_true", help='use gpu or not')
parser.add_argument('--workers', type=int, default=1, help='workers')
# 检查是否是local或online，不是则报错
args = parser.parse_args()
print("args:", args)


app = Sanic("pdf_parser_server")
# 接收二进制 PDF 上传，上限对齐主服务（128MB）并留出余量
app.config.REQUEST_MAX_SIZE = 256 * 1024 * 1024


@app.before_server_start
async def init_pdf_parser(app, loop):
    start = time.time()
    app.ctx.pdf_parser = PdfLoader(device=torch.device('cpu') if not args.use_gpu else torch.device('cuda'))
    end = time.time()
    print(f'init pdf_parser cost {end - start}s', flush=True)


@app.post("/pdfparser")
async def pdf_parser(request: Request):
    filename = safe_get(request, 'filename')
    if not filename:
        return json({"error": "filename is required"}, status=400)

    pdf_bytes = request.body
    if not pdf_bytes:
        return json({"error": "No PDF data provided"}, status=400)

    # 底层引擎需要真实文件路径来构造输出目录，先把二进制写入临时目录
    tmp_dir = tempfile.mkdtemp(prefix="pdf_parser_")
    tmp_pdf_path = os.path.join(tmp_dir, os.path.basename(filename))
    try:
        with open(tmp_pdf_path, 'wb') as f:
            f.write(pdf_bytes)

        pdf_parser_: PdfLoader = request.app.ctx.pdf_parser
        save_dir = os.path.join(tmp_dir, 'out')
        markdown_file = pdf_parser_.load_to_markdown(tmp_pdf_path, save_dir)

        if not markdown_file or not os.path.exists(markdown_file):
            return json({"error": "PDF parse failed"}, status=500)

        with open(markdown_file, 'r', encoding='utf-8') as f:
            markdown_text = f.read()

        # 解析结果目录（markdown 所在目录）里的图片一并打包返回
        img_dir = os.path.dirname(markdown_file)
        images = []
        if os.path.isdir(img_dir):
            for fn in sorted(os.listdir(img_dir)):
                if fn.lower().endswith('.jpg'):
                    with open(os.path.join(img_dir, fn), 'rb') as f:
                        images.append({"name": fn, "data": base64.b64encode(f.read()).decode('utf-8')})

        return json({
            "markdown": markdown_text,
            "markdown_filename": os.path.basename(markdown_file),
            "images": images,
        })
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == '__main__':
    app.run(host="0.0.0.0", port=9009, workers=args.workers, single_process=True)
