"""Public content read Lambda (no auth).

Returns the published sections, ordered. This is the always-on read path so
the public site keeps working while the ECS backend is lightswitched off.
"""

import json
import os

import boto3
from boto3.dynamodb.conditions import Attr

table = boto3.resource("dynamodb").Table(os.environ["CONTENT_TABLE"])


def handler(event, context):
    # Only items that have been published appear on the public site.
    resp = table.scan(FilterExpression=Attr("published").exists())
    items = sorted(resp.get("Items", []), key=lambda x: int(x.get("order", 0)))

    sections = [
        {
            "id": i["pk"].split("#", 1)[1],
            "kind": i.get("kind", "custom"),
            "title": i.get("title"),
            "order": int(i.get("order", 0)),
            "data": i["published"],
        }
        for i in items
        if i["pk"].startswith("SECTION#")
    ]

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-cache",
        },
        # default=str handles DynamoDB Decimal values.
        "body": json.dumps({"sections": sections}, default=str),
    }
