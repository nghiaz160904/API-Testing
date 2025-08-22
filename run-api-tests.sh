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

# Define collections to test
collections=(
    "GET_Categories_Tree_API.postman_collection.json"
    "GET_Category_Details_API.postman_collection.json"
    "POST_Categories_API.postman_collection.json"
)

# Run tests for each collection
overall_status=0
for collection in "${collections[@]}"; do
    collection_name=$(basename "$collection" .postman_collection.json)
    report_file="reports/${collection_name}_report.html"
    log_file="reports/${collection_name}.log"
    
    echo -e "\n🧪 Testing Collection: $collection_name"
    
    newman run "./tests/api/$collection" \
        --environment "./tests/api/environment.json" \
        --reporters cli,htmlextra \
        --reporter-htmlextra-export "$report_file" \
        --reporter-htmlextra-title "$collection_name Test Report" 2>&1 | tee "$log_file"
    
    # Capture exit status
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "❌ $collection_name tests failed"
        overall_status=1
    else
        echo "✅ $collection_name tests passed"
    fi
    
    # Generate summary
    echo "📊 Report: file://$(pwd)/$report_file"
    echo "📋 Log: $(pwd)/$log_file"
done

# Final status
if [ $overall_status -eq 0 ]; then
    echo -e "\n🎉 All test collections passed successfully!"
else
    echo -e "\n🔴 Some test collections failed. Check individual reports."
fi

# Clean up
echo "🧹 Stopping Docker containers..."
docker compose down

exit $overall_status