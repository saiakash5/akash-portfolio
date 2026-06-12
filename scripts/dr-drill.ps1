# DR drill: fail over to us-west-2 and back.
#
#   .\scripts\dr-drill.ps1            # run the drill (failover)
#   .\scripts\dr-drill.ps1 -Restore   # fail back and scale the DR region down
#
# What failover does:
#   1. Scale the dormant us-west-2 services from 0 -> 1 (pilot light -> warm)
#   2. Invert the Route 53 health check, simulating a primary-region outage
#   3. Watch DNS flip api.thesaiakash.com to the secondary ALB
#
# Cost: a drill costs roughly a few cents per hour while the secondary runs.
# Always finish with -Restore.

param([switch]$Restore)

$ErrorActionPreference = "Stop"
$Secondary = "us-west-2"
$Cluster = "portfolio-secondary"
$Services = @("portfolio-secondary-profile", "portfolio-secondary-contact")
$ApiHost = "api.thesaiakash.com"

# The single health check in the account is the primary-API one.
$HealthCheckId = aws route53 list-health-checks --query "HealthChecks[0].Id" --output text

function Set-SecondaryScale([int]$Count) {
    foreach ($svc in $Services) {
        aws ecs update-service --cluster $Cluster --service $svc `
            --desired-count $Count --region $Secondary `
            --query "service.serviceName" --output text
    }
}

if ($Restore) {
    Write-Host "`n=== FAILBACK ===" -ForegroundColor Cyan

    Write-Host "[1/3] Restoring Route 53 health check (un-inverting)..."
    aws route53 update-health-check --health-check-id $HealthCheckId --no-inverted | Out-Null

    Write-Host "[2/3] Waiting for primary to take traffic back (DNS TTL ~60s)..."
    Start-Sleep -Seconds 90
    curl.exe -s -o /nul -w "api status after failback: %{http_code}`n" "https://$ApiHost/api/profile"

    Write-Host "[3/3] Scaling secondary back to 0 (pilot light)..."
    Set-SecondaryScale 0

    Write-Host "`nFailback complete. Secondary is dormant again." -ForegroundColor Green
    exit 0
}

Write-Host "`n=== DR DRILL: failover to $Secondary ===" -ForegroundColor Cyan

Write-Host "[1/4] Scaling up secondary services (0 -> 1)..."
Set-SecondaryScale 1

Write-Host "[2/4] Waiting for secondary services to become stable (~2-4 min)..."
aws ecs wait services-stable --cluster $Cluster --services $Services --region $Secondary
Write-Host "      Secondary is healthy and serving behind its ALB."

Write-Host "[3/4] Simulating primary outage (inverting the health check)..."
aws route53 update-health-check --health-check-id $HealthCheckId --inverted | Out-Null

Write-Host "[4/4] Waiting for Route 53 to fail over (health check interval + DNS TTL)..."
Start-Sleep -Seconds 120

$secondaryAlb = aws elbv2 describe-load-balancers --region $Secondary `
    --query "LoadBalancers[0].DNSName" --output text
$apiIps = (Resolve-DnsName $ApiHost -Type A | Where-Object Type -eq "A").IPAddress
$albIps = (Resolve-DnsName $secondaryAlb -Type A | Where-Object Type -eq "A").IPAddress
$failedOver = @($apiIps | Where-Object { $albIps -contains $_ }).Count -gt 0

curl.exe -s -o /nul -w "api status during failover: %{http_code}`n" "https://$ApiHost/api/profile"

if ($failedOver) {
    Write-Host "`nSUCCESS: $ApiHost now resolves to the $Secondary ALB." -ForegroundColor Green
} else {
    Write-Host "`nDNS has not flipped yet — health checks + TTL can take another minute or two." -ForegroundColor Yellow
    Write-Host "Re-check with: Resolve-DnsName $ApiHost"
}

Write-Host "`nWhen finished, ALWAYS run: .\scripts\dr-drill.ps1 -Restore" -ForegroundColor Yellow
