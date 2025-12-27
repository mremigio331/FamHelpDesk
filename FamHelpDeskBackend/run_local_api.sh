#!/bin/bash

# Parse command line arguments
USE_HTTPS=false
for arg in "$@"
do
    if [ "$arg" == "--https" ]; then
        USE_HTTPS=true
    fi
done

export STAGE="Dev"
export COGNITO_USER_POOL_ID=$(
    aws cognito-idp list-user-pools --region us-west-2 --max-results 60 --query "UserPools[?Name=='FamHelpDesk-UserPool-Testing'].Id" --output text)
export COGNITO_CLIENT_ID=$(aws cognito-idp list-user-pools --max-results 60 --region us-west-2 \
--query "UserPools[].Id" --output text | xargs -n1 -I {} aws cognito-idp list-user-pool-clients \
    --user-pool-id {} --region us-west-2 \
    --query "UserPoolClients[?contains(ClientName, 'FamHelpDeskUserPoolClientTesting')].ClientId" \
    --output text
)
export COGNITO_REGION="us-west-2"
export COGNITO_API_REDIRECT_URI="https://localhost:5000/"
export COGNITO_DOMAIN="https://famhelpdesk-testing.auth.us-west-2.amazoncognito.com"
export API_URL="https://api.testing.famhelpdesk.com"

# Run with or without HTTPS based on flag
if [ "$USE_HTTPS" = true ]; then
    echo "Starting API with HTTPS..."
    python3 fam_help_desk_local_api.py --https
else
    echo "Starting API with HTTP..."
    python3 fam_help_desk_local_api.py
fi