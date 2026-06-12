# Lightswitch: manually turn the backend on/off outside showcase hours.
#
#   .\scripts\lightswitch.ps1 on       # wake the backend (e.g. weekend demo)
#   .\scripts\lightswitch.ps1 off      # put it back to sleep
#   .\scripts\lightswitch.ps1 status   # what's running right now
#
# The automatic schedule (Application Auto Scaling, America/Chicago):
#   ON  8:00 AM  Mon-Fri
#   OFF 4:00 PM  every day
#
# A manual "on" therefore lasts at most until the next 4:00 PM — you can't
# accidentally leave it running for a week. The frontend site itself stays
# up 24/7; while the backend sleeps, only the contact form is degraded
# (it shows a mailto fallback).

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("on", "off", "status")]
    [string]$Action
)

$ErrorActionPreference = "Stop"
$Cluster = "portfolio-primary"
$Region = "us-east-1"
$Services = @("portfolio-primary-profile", "portfolio-primary-contact")

if ($Action -eq "status") {
    aws ecs describe-services --cluster $Cluster --services $Services --region $Region `
        --query "services[].{service:serviceName,desired:desiredCount,running:runningCount}" --output table
    exit 0
}

$count = if ($Action -eq "on") { 1 } else { 0 }

foreach ($svc in $Services) {
    aws ecs update-service --cluster $Cluster --service $svc `
        --desired-count $count --region $Region `
        --query "service.serviceName" --output text
}

if ($Action -eq "on") {
    Write-Host "Waking up... ALB health checks take ~2-3 minutes." -ForegroundColor Cyan
    aws ecs wait services-stable --cluster $Cluster --services $Services --region $Region
    curl.exe -s -o /nul -w "https://api.thesaiakash.com/api/profile -> HTTP %{http_code}`n" https://api.thesaiakash.com/api/profile
    Write-Host "Backend is live. It will auto-sleep at the next 4:00 PM Central." -ForegroundColor Green
} else {
    Write-Host "Backend going to sleep (tasks drain in ~1 minute)." -ForegroundColor Green
}
