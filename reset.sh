#!/bin/bash
echo "🧹 Cleaning up environment..."
killall terraform 2>/dev/null
sleep 2

# Destroy existing resources properly
if [ -f terraform.tfstate ]; then
    terraform destroy -auto-approve -lock=false
fi

rm -rf .terraform/ terraform.tfstate* lambda.zip package/

# Restart Containers
docker-compose down -v
docker-compose up -d

echo "⏳ Waiting 25s for LocalStack APIs to wake up..."
sleep 25

# Verify LocalStack is healthy
if ! curl -s http://localhost:4566/_localstack/health | grep -q "available"; then
    echo "❌ LocalStack is not responding. Check docker logs."
    exit 1
fi

echo "📦 Packaging Lambda..."
mkdir package
pip install --target ./package pymongo > /dev/null
cp index.py ./package/
cd package && zip -r ../lambda.zip . > /dev/null && cd ..

echo "🏗️  Deploying..."
terraform init
terraform apply -auto-approve -lock=false

echo "✅ Deployment finished."
terraform output api_url