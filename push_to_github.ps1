$GITHUB_USER = "SHARANMAYYA6070"
$REPO_NAME   = "sync_fifo"
$DESCRIPTION = "Parameterized Synchronous FIFO - RTL Design and Verification in SystemVerilog"

Write-Host ""
Write-Host "========================================"
Write-Host "  Sync FIFO - GitHub Push Script"
Write-Host "========================================"
Write-Host ""
Write-Host "Enter your GitHub Personal Access Token (PAT):"
$PAT = Read-Host "PAT"

Write-Host ""
Write-Host "Creating GitHub repository..."

$body = "{`"name`":`"$REPO_NAME`",`"description`":`"$DESCRIPTION`",`"private`":false,`"auto_init`":false}"

$headers = @{
    Authorization = "token $PAT"
    Accept = "application/vnd.github.v3+json"
}

Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method POST -Headers $headers -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue

Write-Host "Setting up git..."

git init
git config user.name $GITHUB_USER
git config user.email "sharanmayya929@gmail.com"
git add .
git commit -m "Initial commit: Parameterized Synchronous FIFO - RTL Design and Verification"
git branch -M main
git remote remove origin 2>$null
git remote add origin "https://${GITHUB_USER}:${PAT}@github.com/${GITHUB_USER}/${REPO_NAME}.git"
git push -u origin main

Write-Host ""
Write-Host "========================================"
Write-Host "Done! View repo at:"
Write-Host "https://github.com/$GITHUB_USER/$REPO_NAME"
Write-Host "========================================"
