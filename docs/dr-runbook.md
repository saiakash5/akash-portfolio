# Disaster Recovery Runbook

## Architecture recap

- **Primary**: us-east-1 — full stack, services running.
- **Secondary**: us-west-2 — identical infrastructure (VPC, ALB, ECS cluster,
  task definitions, certs), services scaled to **0** (pilot light).
- **Database**: DynamoDB Global Tables — bi-directionally replicated, both
  regions can read/write at any time. No promotion step needed.
- **Images**: ECR replicates pushes from us-east-1 to us-west-2 automatically.
- **DNS**: `api.thesaiakash.com` uses Route 53 failover routing. A health
  check probes the primary ALB (`/api/profile` over HTTPS) every 30s; after 3
  failures (~90s), DNS flips to the secondary ALB.
- **Frontend**: CloudFront + S3 is global and unaffected by a regional outage.
  Its `/api/*` origin points at `api.thesaiakash.com`, so it follows the
  failover automatically.

## Real outage: what happens automatically

1. Primary ALB stops answering → health check fails 3 times (~90 seconds).
2. Route 53 starts answering `api.thesaiakash.com` with the secondary ALB.
3. **Nothing is serving there yet** — secondary runs 0 tasks. RTO depends on
   the manual scale-up below.

## Real outage: manual steps (RTO target ~5 minutes)

```powershell
aws ecs update-service --cluster portfolio-secondary --service portfolio-secondary-profile --desired-count 1 --region us-west-2
aws ecs update-service --cluster portfolio-secondary --service portfolio-secondary-contact --desired-count 1 --region us-west-2
aws ecs wait services-stable --cluster portfolio-secondary --services portfolio-secondary-profile portfolio-secondary-contact --region us-west-2
curl https://api.thesaiakash.com/api/profile     # should answer from us-west-2
```

Data note: DynamoDB global tables replicate in ~1 second; at this traffic
level, data loss in a regional failure is effectively zero (RPO ≈ 0).

## Failback (after the primary region recovers)

1. Confirm primary ALB targets are healthy in the us-east-1 console.
2. The health check recovers on its own; Route 53 flips DNS back to primary
   automatically (failover PRIMARY records always win when healthy).
3. Scale secondary back to 0:

```powershell
aws ecs update-service --cluster portfolio-secondary --service portfolio-secondary-profile --desired-count 0 --region us-west-2
aws ecs update-service --cluster portfolio-secondary --service portfolio-secondary-contact --desired-count 0 --region us-west-2
```

## Practice drill (no real outage)

```powershell
.\scripts\dr-drill.ps1            # scale up secondary, simulate primary failure
.\scripts\dr-drill.ps1 -Restore   # fail back, scale secondary to 0
```

The drill inverts the Route 53 health check instead of breaking anything —
the primary keeps running, only DNS behavior changes. Run it quarterly;
each drill costs a few cents.

## Known limitations (intentional tradeoffs)

- Scale-up is manual: a Lambda triggered by the health-check CloudWatch alarm
  could automate it (future work).
- The first request after failover may be slow while CloudFront re-resolves
  its origin DNS.
- SNS contact notifications publish to a topic in us-east-1; during a full
  us-east-1 outage, messages still land in DynamoDB but emails are delayed
  until the region recovers.
