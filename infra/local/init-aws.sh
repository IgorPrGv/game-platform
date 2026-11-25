#!/usr/bin/env bash
# Prepara os emuladores do ambiente local. Pode rodar várias vezes.
set -euo pipefail

S3="--endpoint-url http://s3:8333"
DDB="--endpoint-url http://dynamodb:8000"
SQS="--endpoint-url http://sqs:9324"

echo "S3: bucket ${S3_BUCKET}"
if ! aws $S3 s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  aws $S3 s3api create-bucket --bucket "$S3_BUCKET" >/dev/null
fi
aws $S3 s3api put-bucket-cors --bucket "$S3_BUCKET" --cors-configuration file:///init/s3-cors.json \
  || echo "  aviso: o emulador não aceitou o CORS"

echo "DynamoDB: tabela ${DYNAMODB_TABLE}"
if ! aws $DDB dynamodb describe-table --table-name "$DYNAMODB_TABLE" >/dev/null 2>&1; then
  aws $DDB dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --billing-mode PAY_PER_REQUEST \
    --attribute-definitions \
      AttributeName=steamAppID,AttributeType=S \
      AttributeName=feed,AttributeType=S \
      AttributeName=dealRating,AttributeType=N \
    --key-schema AttributeName=steamAppID,KeyType=HASH \
    --global-secondary-indexes \
      'IndexName=feed-rating,KeySchema=[{AttributeName=feed,KeyType=HASH},{AttributeName=dealRating,KeyType=RANGE}],Projection={ProjectionType=ALL}' \
    >/dev/null
  aws $DDB dynamodb update-time-to-live --table-name "$DYNAMODB_TABLE" \
    --time-to-live-specification Enabled=true,AttributeName=expiresAt >/dev/null
fi

echo "SQS: fila ${SQS_QUEUE}"
for i in $(seq 1 30); do
  if aws $SQS sqs get-queue-url --queue-name "$SQS_QUEUE" >/dev/null 2>&1; then break; fi
  if [ "$i" = 30 ]; then echo "  erro: fila não encontrada"; exit 1; fi
  sleep 1
done

echo "Pronto."
