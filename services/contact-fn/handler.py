"""Contact form Lambda — replaces the FastAPI/ECS contact-service.

Validates the submission, stores it in the messages DynamoDB table, and emails
a notification via SNS. Always-on and scale-to-zero, so the contact form works
24/7 with no ECS to keep awake.
"""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3

table = boto3.resource("dynamodb").Table(os.environ["MESSAGES_TABLE"])
sns = boto3.client("sns")
TOPIC_ARN = os.environ.get("TOPIC_ARN") or None


def _resp(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _resp(400, {"error": "invalid JSON"})

    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    message = (body.get("message") or "").strip()

    if not name or not message or "@" not in email:
        return _resp(422, {"error": "name, a valid email, and message are required"})

    item = {
        "pk": f"MESSAGE#{uuid.uuid4()}",
        "name": name[:200],
        "email": email[:200],
        "message": message[:5000],
        "received_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        table.put_item(Item=item)
    except Exception:  # noqa: BLE001
        return _resp(503, {"error": "could not store message"})

    # Best-effort notification — the message is already saved.
    if TOPIC_ARN:
        try:
            sns.publish(
                TopicArn=TOPIC_ARN,
                Subject=f"Portfolio contact from {name}",
                Message=f"From: {name} <{email}>\n\n{message}",
            )
        except Exception:  # noqa: BLE001
            pass

    return _resp(201, {"id": item["pk"], "status": "received"})
