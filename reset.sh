#!/bin/bash
echo "🧹 Cleaning up existing environment..."

# 1. Kill lingering processes
killall terraform 2>/dev/null
sleep 2

# 2. Attempt a clean teardown if state exists
if [ -f terraform.tfstate ]; then
    echo "🗑️  Tearing down existing cloud resources..."
    terraform destroy -auto-approve -lock=false
fi

# 3. Wipe state and temp files
rm -f .terraform.tfstate.lock.info
rm -rf .terraform/
rm -f terraform.tfstate*
rm -f lambda.zip

# 4. Reset Containers
docker-compose down -v
docker-compose up -d

echo "⏳ Waiting for LocalStack Services (S3, SecretsManager, Iam)..."
# HEALTH CHECK LOOP
MAX_RETRIES=30
COUNT=0
while ! curl -s http://localhost:4566/_localstack/health | grep -q "\"s3\": \"available\""; do
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ LocalStack failed to initialize in time."
        exit 1
    fi
    echo -n "."
    sleep 2
    COUNT=$((COUNT+1))
done
echo -e "\n✅ LocalStack Services are READY."

# 5. Package App Tier
echo "📦 Packaging Bank Logic..."
rm -rf package && mkdir package
pip install --target ./package pymongo > /dev/null
cp index.py ./package/
cd package && zip -r ../lambda.zip . > /dev/null && cd ..

# 6. Re-deploy
echo "🏗️  Re-deploying Architecture..."
terraform init
terraform apply -auto-approve -lock=false

echo "✅ Clean deployment finished."
terraform output api_url