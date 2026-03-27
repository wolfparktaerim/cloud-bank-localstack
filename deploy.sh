#!/bin/bash
if [ -f .env ]; then export $(grep -v '^#' .env | xargs); fi

# Package Lambda with dependencies
rm -rf package lambda.zip && mkdir package
pip install --target ./package pymongo
cp index.py ./package/
cd package && zip -r ../lambda.zip . > /dev/null && cd ..

docker-compose up -d
echo "⏳ Waiting 15s for LocalStack..."
sleep 15

terraform init
terraform apply -auto-approve
terraform output api_url