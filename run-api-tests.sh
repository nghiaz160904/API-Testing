#!/bin/bash

echo "🚀 Starting API Login Tests..."

# Tạo thư mục reports nếu chưa tồn tại
mkdir -p reports

# Function kiểm tra lệnh có tồn tại
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Kiểm tra và cài đặt Newman nếu cần
if ! command_exists newman; then
    echo "📥 Newman not found, installing..."
    if command_exists sudo; then
        sudo npm install -g newman newman-reporter-htmlextra
    else
        npm install -g newman newman-reporter-htmlextra
    fi
fi

# Khởi động Docker
echo "📦 Starting Docker containers..."
docker compose -f docker-compose.yml up -d --force-recreate

# Chờ dịch vụ sẵn sàng (cải tiến: kiểm tra thực sự thay vì sleep)
echo "⏳ Waiting for services to be ready..."
sleep 30

# Setup database
echo "🗄️ Setting up database..."
docker compose exec laravel-api php artisan migrate --force
docker compose exec laravel-api php artisan db:seed --force

# Chạy tests với logging chi tiết
echo "🧪 Running API tests..."
newman run "./tests/api/collection.json" \
  --environment "./tests/api/environment.json" \
  --reporters cli,htmlextra \
  --reporter-htmlextra-export "reports/api-test-report.html" \
  --reporter-htmlextra-title "API Test Report" 2>&1 | tee reports/test.log

# Kiểm tra kết quả
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ All tests passed successfully!"
else
    echo "❌ Some tests failed. Check the report and log for details."
    echo "📋 Log file: reports/test.log"
fi

# Mở báo cáo nếu tồn tại
if [ -f "reports/api-test-report.html" ]; then
    echo "📊 Opening test report..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "reports/api-test-report.html"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "reports/api-test-report.html"
    fi
else
    echo "⚠️ Test report not generated. Check logs for errors."
fi

# Dọn dẹp
echo "🧹 Stopping Docker containers..."
docker compose down

echo "🏁 Test execution completed!"