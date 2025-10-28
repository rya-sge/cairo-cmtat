#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Deployment script for CMTAT tokens on Starknet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NETWORK="${NETWORK:-sepolia}"
ACCOUNT="${ACCOUNT:-default}"

# Default parameters
DEFAULT_ADMIN="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
DEFAULT_RECIPIENT="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
DEFAULT_INITIAL_SUPPLY="1000000000000000000000000" # 1,000,000 tokens with 18 decimals
DEFAULT_TERMS="0x54657374546f6b656e" # "TestToken" in hex
DEFAULT_FLAG="0x1"
DEFAULT_TYPE="working" # Default contract type

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  CMTAT Token Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --network NETWORK       Starknet network (default: sepolia)"
    echo "  --account ACCOUNT       Account name (default: default)"
    echo "  --admin ADDRESS         Admin address (default: $DEFAULT_ADMIN)"
    echo "  --recipient ADDRESS     Initial token recipient (default: $DEFAULT_RECIPIENT)"
    echo "  --supply AMOUNT         Initial supply (default: $DEFAULT_INITIAL_SUPPLY)"
    echo "  --name NAME             Token name (default: CMTAT Token)"
    echo "  --symbol SYMBOL         Token symbol (default: CMTAT)"
    echo "  --terms TERMS           Terms felt252 (default: $DEFAULT_TERMS)"
    echo "  --flag FLAG             Flag felt252 (default: $DEFAULT_FLAG)"
    echo "  --type TYPE             Contract type: working, standard, light, debt (default: working)"
    echo "  --help                  Display this help message"
    echo ""
    echo "Examples:"
    echo "  Deploy standard CMTAT:"
    echo "    $0 --network sepolia --name \"My Token\" --symbol \"MTK\""
    echo ""
    echo "  Deploy with custom parameters:"
    echo "    $0 --admin 0x123... --supply 10000000 --network mainnet"
    exit 1
}

# Parse command line arguments
ADMIN="$DEFAULT_ADMIN"
RECIPIENT="$DEFAULT_RECIPIENT"
SUPPLY="$DEFAULT_INITIAL_SUPPLY"
NAME="CMTAT Token"
SYMBOL="CMTAT"
TERMS="$DEFAULT_TERMS"
FLAG="$DEFAULT_FLAG"
CONTRACT_TYPE="$DEFAULT_TYPE"

while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --admin)
            ADMIN="$2"
            shift 2
            ;;
        --recipient)
            RECIPIENT="$2"
            shift 2
            ;;
        --supply)
            SUPPLY="$2"
            shift 2
            ;;
        --name)
            NAME="$2"
            shift 2
            ;;
        --symbol)
            SYMBOL="$2"
            shift 2
            ;;
        --terms)
            TERMS="$2"
            shift 2
            ;;
        --flag)
            FLAG="$2"
            shift 2
            ;;
        --type)
            CONTRACT_TYPE="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "  Network: $NETWORK"
echo "  Account: $ACCOUNT"
echo "  Admin: $ADMIN"
echo "  Recipient: $RECIPIENT"
echo "  Initial Supply: $SUPPLY"
echo "  Token Name: $NAME"
echo "  Token Symbol: $SYMBOL"
echo "  Terms: $TERMS"
echo "  Flag: $FLAG"
echo "  Contract Type: $CONTRACT_TYPE"
echo ""

# Check if scarb is installed
if ! command -v scarb &> /dev/null; then
    echo -e "${RED}Error: scarb is not installed${NC}"
    echo "Please install scarb: https://docs.swmansion.com/scarb/"
    exit 1
fi

# Check if starkli is installed
if ! command -v starkli &> /dev/null; then
    echo -e "${RED}Error: starkli is not installed${NC}"
    echo "Please install starkli: https://book.starkli.rs/installation"
    exit 1
fi

# Build the project
echo -e "${GREEN}Building project...${NC}"
scarb build

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}Build successful!${NC}"
echo ""

# Determine contract file based on type
case "$CONTRACT_TYPE" in
    working)
        CONTRACT_FILE="cairo_cmtat_WorkingCMTAT.contract_class.json"
        CONTRACT_NAME="WorkingCMTAT"
        ;;
    standard)
        CONTRACT_FILE="cairo_cmtat_StandardCMTAT.contract_class.json"
        CONTRACT_NAME="StandardCMTAT"
        ;;
    light)
        CONTRACT_FILE="cairo_cmtat_LightCMTAT.contract_class.json"
        CONTRACT_NAME="LightCMTAT"
        ;;
    debt)
        CONTRACT_FILE="cairo_cmtat_DebtCMTAT.contract_class.json"
        CONTRACT_NAME="DebtCMTAT"
        ;;
    *)
        echo -e "${RED}Invalid contract type: $CONTRACT_TYPE${NC}"
        echo "Valid types: working, standard, light, debt"
        exit 1
        ;;
esac

# Deploy the contract
echo -e "${GREEN}Deploying $CONTRACT_NAME contract...${NC}"

# Declare the contract
echo -e "${YELLOW}Declaring contract...${NC}"
DECLARE_OUTPUT=$(starkli declare \
    target/dev/$CONTRACT_FILE \
    --network "$NETWORK" \
    --account "$ACCOUNT" 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}Declaration failed:${NC}"
    echo "$DECLARE_OUTPUT"
    exit 1
fi

# Extract class hash from output
CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oP 'Class hash declared: \K0x[a-fA-F0-9]+' || echo "$DECLARE_OUTPUT" | grep -oP '0x[a-fA-F0-9]{64}' | head -1)

if [ -z "$CLASS_HASH" ]; then
    echo -e "${YELLOW}Could not extract class hash, checking if already declared...${NC}"
    CLASS_HASH=$(echo "$DECLARE_OUTPUT" | grep -oP 'Class hash: \K0x[a-fA-F0-9]+')
fi

echo -e "${GREEN}Class Hash: $CLASS_HASH${NC}"
echo ""

# Deploy the contract
echo -e "${YELLOW}Deploying contract...${NC}"
DEPLOY_OUTPUT=$(starkli deploy \
    "$CLASS_HASH" \
    "$ADMIN" \
    str:"$NAME" \
    str:"$SYMBOL" \
    "$SUPPLY" \
    "$RECIPIENT" \
    "$TERMS" \
    "$FLAG" \
    --network "$NETWORK" \
    --account "$ACCOUNT" 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed:${NC}"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

# Extract contract address
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Contract deployed: \K0x[a-fA-F0-9]+' || echo "$DEPLOY_OUTPUT" | grep -oP '0x[a-fA-F0-9]{64}' | head -1)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Contract Address: $CONTRACT_ADDRESS${NC}"
echo -e "${GREEN}Class Hash: $CLASS_HASH${NC}"
echo -e "${GREEN}Network: $NETWORK${NC}"
echo ""
echo -e "${YELLOW}Save these details for future reference!${NC}"
echo ""

# Save deployment info
DEPLOYMENT_FILE="deployments/${NETWORK}_$(date +%Y%m%d_%H%M%S).json"
mkdir -p deployments

cat > "$DEPLOYMENT_FILE" << EOF
{
  "network": "$NETWORK",
  "contract_address": "$CONTRACT_ADDRESS",
  "class_hash": "$CLASS_HASH",
  "admin": "$ADMIN",
  "recipient": "$RECIPIENT",
  "initial_supply": "$SUPPLY",
  "token_name": "$NAME",
  "token_symbol": "$SYMBOL",
  "terms": "$TERMS",
  "flag": "$FLAG",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo -e "${GREEN}Deployment info saved to: $DEPLOYMENT_FILE${NC}"
echo ""

# Display next steps
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Verify the contract on Starkscan or Voyager"
echo "2. Test token functionality (mint, transfer, freeze)"
echo "3. Grant additional roles if needed"
echo ""
echo -e "${YELLOW}Example commands:${NC}"
echo "  # Check balance"
echo "  starkli call $CONTRACT_ADDRESS balance_of $RECIPIENT --network $NETWORK"
echo ""
echo "  # Mint tokens (requires MINTER_ROLE)"
echo "  starkli invoke $CONTRACT_ADDRESS mint <recipient> <amount> --network $NETWORK --account $ACCOUNT"
echo ""
echo "  # Freeze address (requires ENFORCER_ROLE)"
echo "  starkli invoke $CONTRACT_ADDRESS freeze_address <address> --network $NETWORK --account $ACCOUNT"
echo ""
