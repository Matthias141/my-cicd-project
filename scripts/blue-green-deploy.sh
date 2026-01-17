#!/bin/bash
set -e

# Blue-Green Deployment Script with Canary Release
# This script performs a gradual traffic shift from blue to green version
# with automatic rollback on errors

FUNCTION_NAME=${1}
NEW_VERSION=${2}
ROLLBACK_ON_ERROR=${3:-true}

if [ -z "$FUNCTION_NAME" ] || [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <function-name> <new-version> [rollback-on-error]"
    exit 1
fi

echo "🚀 Starting Blue-Green Canary Deployment"
echo "Function: $FUNCTION_NAME"
echo "New Version: $NEW_VERSION"
echo "Auto Rollback: $ROLLBACK_ON_ERROR"
echo ""

# Get current blue version
CURRENT_BLUE_VERSION=$(aws lambda get-alias \
    --function-name $FUNCTION_NAME \
    --name blue \
    --query 'FunctionVersion' \
    --output text)

echo "📘 Current Blue Version: $CURRENT_BLUE_VERSION"
echo "🟢 New Green Version: $NEW_VERSION"
echo ""

# Update green alias to new version
echo "1️⃣  Updating green alias to version $NEW_VERSION..."
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name green \
    --function-version $NEW_VERSION \
    --description "Green version - deployment in progress"

echo "✅ Green alias updated"
echo ""

# Function to check health
check_health() {
    local version=$1
    local alias=$2

    echo "🏥 Health check for $alias (version $version)..."

    # Get error count in last 1 minute
    local end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
    local start_time=$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%S)

    local errors=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Errors \
        --dimensions Name=FunctionName,Value=$FUNCTION_NAME Name=ExecutedVersion,Value=$version \
        --start-time $start_time \
        --end-time $end_time \
        --period 60 \
        --statistics Sum \
        --query 'Datapoints[0].Sum' \
        --output text)

    if [ "$errors" == "None" ]; then
        errors=0
    fi

    echo "   Errors in last minute: $errors"

    if [ "$errors" -gt 5 ]; then
        echo "   ❌ Health check FAILED (too many errors)"
        return 1
    else
        echo "   ✅ Health check PASSED"
        return 0
    fi
}

# Function to shift traffic
shift_traffic() {
    local weight=$1
    local blue_version=$2
    local green_version=$3

    echo "⚖️  Shifting traffic: Blue $((100-weight))% / Green ${weight}%..."

    if [ $weight -eq 100 ]; then
        # Full cutover - point live to green, no routing config
        aws lambda update-alias \
            --function-name $FUNCTION_NAME \
            --name live \
            --function-version $green_version \
            --description "Live - fully on green version $green_version"
    else
        # Weighted routing
        local green_weight=$(awk "BEGIN {print $weight/100}")

        aws lambda update-alias \
            --function-name $FUNCTION_NAME \
            --name live \
            --function-version $blue_version \
            --routing-config "AdditionalVersionWeights={$green_version=$green_weight}" \
            --description "Live - canary $weight% on green version $green_version"
    fi

    echo "✅ Traffic shifted"
}

# Function to rollback
rollback() {
    echo ""
    echo "🔴 ROLLBACK INITIATED"
    echo "Reverting to blue version $CURRENT_BLUE_VERSION..."

    aws lambda update-alias \
        --function-name $FUNCTION_NAME \
        --name live \
        --function-version $CURRENT_BLUE_VERSION \
        --description "Live - rolled back to blue version $CURRENT_BLUE_VERSION"

    echo "✅ Rollback complete - traffic back on blue version"
    exit 1
}

# Canary Deployment Stages
STAGES=(10 25 50 100)
WAIT_TIME=60  # seconds between stages

for stage in "${STAGES[@]}"; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Stage: $stage% traffic to green version"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Shift traffic
    shift_traffic $stage $CURRENT_BLUE_VERSION $NEW_VERSION

    # Wait for metrics
    echo "⏳ Waiting $WAIT_TIME seconds for metrics..."
    sleep $WAIT_TIME

    # Health check
    if ! check_health $NEW_VERSION "green"; then
        if [ "$ROLLBACK_ON_ERROR" == "true" ]; then
            rollback
        else
            echo "⚠️  Health check failed but auto-rollback is disabled"
            echo "Continue? (y/n)"
            read -r response
            if [ "$response" != "y" ]; then
                rollback
            fi
        fi
    fi

    if [ $stage -lt 100 ]; then
        echo "✅ Stage $stage% successful, proceeding to next stage..."
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All stages completed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Update blue alias to new version (swap blue/green)
echo ""
echo "🔄 Promoting green to blue..."
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name blue \
    --function-version $NEW_VERSION \
    --description "Blue version - promoted from green $NEW_VERSION"

echo "✅ Blue alias updated to version $NEW_VERSION"

echo ""
echo "🎉 Deployment Complete!"
echo "   Previous blue: $CURRENT_BLUE_VERSION"
echo "   New blue: $NEW_VERSION"
echo "   Live traffic: 100% on version $NEW_VERSION"
