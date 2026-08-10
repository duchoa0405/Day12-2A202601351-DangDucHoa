# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [ ] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [ ] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [ ] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [ ] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [ ] Có `HEALTHCHECK` gọi vào endpoint /health
#   [ ] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

FROM python:3.11-slim AS builder


WORKDIR /app

#Copy riêng requirements để tận dụng cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---Giai doan 2: Runtime (chay that)---

FROM python:3.11-slim

WORKDIR /app

#tao user thuong cos ten appuser
RUN useradd -m appuser

# Copy THU VIEN da cai o stage builder sang
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

COPY --from=builder /usr/local/bin /usr/local/bin

# Copy SOURCE CODE
COPY . .

# chuyeenr quyen so huu thu muc cho appuser
RUN chown -R appuser:appuser /app


#chuyen sang chay tren user(no run root)
USER appuser

# Biến môi trường PORT (Cloud thường tự động cấp giá trị cho biến này, mặc định ta để 8000)
ENV PORT=8000
EXPOSE ${PORT}

# Khai báo Healthcheck (dùng python gọi vào /health)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:${PORT}/health', timeout=3)"     

# Khởi động server
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port $PORT"]
