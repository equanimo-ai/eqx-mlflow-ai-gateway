#!/bin/sh
# Runs inside LocalStack once it is ready. Creates the AWS resources the gateway talks to.
set -eu

# Same name as the production stream owned by eqx-events-processor.
awslocal kinesis create-stream --stream-name eqx-raw-ai-events --shard-count 1

# FIFO queue names must end in .fifo.
dlq_url=$(awslocal sqs create-queue \
  --queue-name eqx-ai-gateway-policy-actions-dlq.fifo \
  --attributes FifoQueue=true \
  --query QueueUrl --output text)
dlq_arn=$(awslocal sqs get-queue-attributes \
  --queue-url "$dlq_url" \
  --attribute-names QueueArn \
  --query Attributes.QueueArn --output text)

cat > /tmp/policy-actions-attributes.json <<EOF
{
  "FifoQueue": "true",
  "RedrivePolicy": "{\"deadLetterTargetArn\":\"${dlq_arn}\",\"maxReceiveCount\":\"5\"}"
}
EOF
awslocal sqs create-queue \
  --queue-name eqx-ai-gateway-policy-actions.fifo \
  --attributes file:///tmp/policy-actions-attributes.json

touch /tmp/eqx-resources-ready
