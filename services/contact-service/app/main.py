"""Contact service — receives contact-form submissions and stores them in DynamoDB.

Local dev: run without TABLE_NAME set and submissions are just logged.
In AWS: ECS task role grants dynamodb:PutItem on the global table.
"""

import logging
import os
import uuid
from datetime import datetime, timezone

import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr, Field

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("contact-service")

TABLE_NAME = os.environ.get("TABLE_NAME")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

app = FastAPI(title="contact-service", version="0.1.0")


class ContactMessage(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    email: EmailStr
    message: str = Field(min_length=1, max_length=5000)


@app.get("/healthz")
def health() -> dict:
    """ALB target-group health check."""
    return {"status": "ok", "region": AWS_REGION}


@app.post("/api/contact", status_code=201)
def submit_contact(msg: ContactMessage) -> dict:
    item = {
        "pk": f"MESSAGE#{uuid.uuid4()}",
        "name": msg.name,
        "email": msg.email,
        "message": msg.message,
        "received_at": datetime.now(timezone.utc).isoformat(),
        "region": AWS_REGION,
    }

    if TABLE_NAME:
        try:
            table = boto3.resource("dynamodb", region_name=AWS_REGION).Table(TABLE_NAME)
            table.put_item(Item=item)
        except Exception:
            logger.exception("Failed to write contact message to DynamoDB")
            raise HTTPException(status_code=503, detail="Could not store message")
    else:
        # Local development — no AWS credentials needed.
        logger.info("TABLE_NAME not set; logging message instead: %s", item)

    return {"id": item["pk"], "status": "received"}
