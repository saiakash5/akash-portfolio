"""Admin content CRUD Lambda (Cognito-protected by the API Gateway authorizer).

By the time this runs, API Gateway has already verified the caller's Cognito
JWT — so this handler trusts the request and focuses on data operations.

Routes (all under /api/admin):
  GET    /sections              list all sections (incl. drafts) for the editor
  POST   /sections              create a new section (starts as a draft)
  PUT    /sections/{id}         update title / order / draft data
  POST   /sections/{id}/publish copy draft -> published (go live)
  DELETE /sections/{id}         remove a section

Data model — one item per section:
  pk        = "SECTION#<uuid>"
  kind      = profile | summary | experience | projects | skills | education | custom
  title     = display heading
  order     = sort position on the public site (number)
  published = live data blob (absent until first publish)
  draft     = pending edits (absent when nothing unpublished)
Reserved DynamoDB words (order, data, etc.) are aliased via #-names.
"""

import json
import os
import time
import uuid

import boto3

table = boto3.resource("dynamodb").Table(os.environ["CONTENT_TABLE"])


def _resp(code, body):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str),
    }


def handler(event, context):
    http = event["requestContext"]["http"]
    method = http["method"]
    # parts e.g. ["api","admin","sections","<id>","publish"]
    parts = [p for p in http["path"].split("/") if p]
    body = json.loads(event["body"]) if event.get("body") else {}

    # /api/admin/sections
    is_collection = len(parts) == 3 and parts[2] == "sections"
    # /api/admin/sections/{id}
    is_item = len(parts) == 4 and parts[2] == "sections"
    # /api/admin/sections/{id}/publish
    is_publish = len(parts) == 5 and parts[4] == "publish"
    section_id = parts[3] if len(parts) >= 4 else None

    if method == "GET" and is_collection:
        items = [i for i in table.scan().get("Items", []) if i["pk"].startswith("SECTION#")]
        items.sort(key=lambda x: int(x.get("order", 0)))
        return _resp(200, {"sections": items})

    if method == "POST" and is_collection:
        sid = str(uuid.uuid4())
        item = {
            "pk": f"SECTION#{sid}",
            "kind": body.get("kind", "custom"),
            "title": body.get("title", "New Section"),
            "order": int(body.get("order", 999)),
            "draft": body.get("data", {}),
            "updatedAt": int(time.time()),
        }
        table.put_item(Item=item)
        return _resp(201, item)

    if method == "PUT" and is_item:
        sets, names, vals = ["#u = :u"], {"#u": "updatedAt"}, {":u": int(time.time())}
        if "title" in body:
            sets.append("#t = :t"); names["#t"] = "title"; vals[":t"] = body["title"]
        if "order" in body:
            sets.append("#o = :o"); names["#o"] = "order"; vals[":o"] = int(body["order"])
        if "data" in body:
            sets.append("#d = :d"); names["#d"] = "draft"; vals[":d"] = body["data"]
        table.update_item(
            Key={"pk": f"SECTION#{section_id}"},
            UpdateExpression="SET " + ", ".join(sets),
            ExpressionAttributeNames=names,
            ExpressionAttributeValues=vals,
        )
        return _resp(200, {"ok": True})

    if method == "POST" and is_publish:
        item = table.get_item(Key={"pk": f"SECTION#{section_id}"}).get("Item")
        if not item:
            return _resp(404, {"error": "not found"})
        live = item.get("draft", item.get("published", {}))
        table.update_item(
            Key={"pk": f"SECTION#{section_id}"},
            UpdateExpression="SET #p = :p REMOVE #d",
            ExpressionAttributeNames={"#p": "published", "#d": "draft"},
            ExpressionAttributeValues={":p": live},
        )
        return _resp(200, {"ok": True})

    if method == "DELETE" and is_item:
        table.delete_item(Key={"pk": f"SECTION#{section_id}"})
        return _resp(200, {"ok": True})

    return _resp(400, {"error": "unhandled route", "method": method, "path": http["path"]})
