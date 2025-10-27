# Cairo CMTAT Implementation

A comprehensive implementation of the Capital Markets Technology Association (CMTAT) token standard in Cairo for Starknet.

## Overview

This implementation provides a production-ready CMTAT framework inspired by the [CMTAT Solidity v3.0.0](https://github.com/CMTA/CMTAT) reference implementation, incorporating insights from [ERC3643-Cairo](https://github.com/Carbonable/ERC3643-Cairo) and [private-CMTAT-aztec](https://github.com/CMTA/private-CMTAT-aztec) implementations.

## Features

### Token Types

- **Standard CMTAT**: Full-featured token with all compliance modules
- **Debt CMTAT**: Specialized for debt securities with interest rates and maturity dates
- **Allowlist CMTAT**: Enhanced with address allowlisting functionality
- **Light CMTAT**: Minimal implementation for basic use cases

### Core Modules

#### Access Control (`access_control.cairo`)
- Role-based access control with CMTAT-specific roles
- Roles: `DEFAULT_ADMIN`, `MINTER`, `BURNER`, `ENFORCER`, `SNAPSHOOTER`
- Admin-has-all-roles pattern for simplified management

#### Pause Module (`pause.cairo`)
- Contract pause and unpause functionality
- Deactivation for permanent shutdown
- Emergency controls for compliance requirements

#### Enforcement Module (`enforcement.cairo`)
- Address freezing and unfreezing
- Partial token freezing per address
- Batch operations for efficient management
- Compliance with regulatory requirements

#### ERC20 Base (`erc20_base.cairo`)
- Core ERC20 functionality with CMTAT extensions
- Transfer validation integration
- Forced transfers for admin operations
- Batch transfer operations

#### Mint Module (`erc20_mint.cairo`)
- Role-based token minting
- Batch minting operations
- Compliance checks during minting

#### Burn Module (`erc20_burn.cairo`)
- Role-based token burning
- Batch burning operations
- Forced burns for emergency situations
- Active balance validation

#### Validation System (`validation.cairo`)
- ERC-1404 compliant transfer restrictions
- Rule engine integration
- Debt engine support for specialized validations
- Comprehensive restriction codes

### External Engine Interfaces

#### Rule Engine (`engines.cairo`)
- ERC-1404 transfer validation
- Configurable business rules
- Integration with external compliance systems

#### Snapshot Engine
- Point-in-time balance snapshots
- Dividend distribution support
- Governance and voting functionality

#### Document Engine
- Document management integration
- Terms and conditions handling
- Legal document associations

#### Debt Engine
- Debt-specific validation rules
- Interest calculation support
- Maturity date enforcement

## Architecture

The implementation follows Cairo's component pattern for modularity and composability:

```
├── interfaces/
│   ├── icmtat.cairo          # Core CMTAT interfaces
│   └── engines.cairo         # External engine interfaces
├── modules/
│   ├── access_control.cairo  # Role-based access control
│   ├── pause.cairo          # Pause and deactivation
│   ├── enforcement.cairo    # Address and token freezing
│   ├── erc20_base.cairo     # Core ERC20 functionality
│   ├── erc20_mint.cairo     # Token minting
│   ├── erc20_burn.cairo     # Token burning
│   └── validation.cairo     # Transfer validation
├── contracts/
│   ├── standard_cmtat.cairo  # Standard token implementation
│   ├── debt_cmtat.cairo     # Debt token implementation
│   ├── allowlist_cmtat.cairo # Allowlist token implementation
│   └── light_cmtat.cairo    # Light token implementation
└── tests/
    └── cmtat_tests.cairo    # Comprehensive test suite
```

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd cairo-cmtat
```

2. Install dependencies:
```bash
scarb build
```

3. Run tests:
```bash
snforge test
```

## Usage

### Deploying a Standard CMTAT Token

```cairo
use cairo_cmtat::contracts::standard_cmtat::StandardCMTAT;

// Deploy with constructor parameters
let admin = contract_address_const::<0x123>();
let name = 'My CMTAT Token';
let symbol = 'MCT';
let decimals = 18_u8;
let terms = 'Terms and Conditions';
let flag = 'FLAG001';

// Constructor will initialize all components
```

### Minting Tokens

```cairo
// Grant minter role to an address
access_control.grant_role('MINTER', minter_address);

// Mint tokens
erc20_mint.mint(recipient, amount);

// Batch mint
erc20_mint.batch_mint(recipients_array, amounts_array);
```

### Managing Allowlists (Allowlist Token)

```cairo
// Add address to allowlist
allowlist_functions.add_to_allowlist(address);

// Batch update allowlist
allowlist_functions.batch_allowlist_update(addresses, statuses);
```

### Enforcement Operations

```cairo
// Freeze an address
enforcement.freeze_address(address);

// Freeze partial tokens
enforcement.freeze_partial_tokens(address, amount);

// Batch freeze addresses
enforcement.batch_freeze_addresses(addresses);
```

## Token Types Comparison

| Feature | Standard | Debt | Allowlist | Light |
|---------|----------|------|-----------|-------|
| Access Control | ✅ | ✅ | ✅ | ✅ |
| Pause/Unpause | ✅ | ✅ | ✅ | ❌ |
| Enforcement | ✅ | ✅ | ✅ | ❌ |
| Minting | ✅ | ✅ | ✅ | ✅ |
| Burning | ✅ | ✅ | ✅ | ❌ |
| Validation | ✅ | ✅ | Enhanced | Minimal |
| Interest Rates | ❌ | ✅ | ❌ | ❌ |
| Allowlisting | ❌ | ❌ | ✅ | ❌ |

## Compliance Features

### ERC-1404 Compliance
- Standardized restriction codes
- `detect_transfer_restriction()` function
- `message_for_transfer_restriction()` function

### Transfer Restrictions
- Sender/recipient validation
- Balance sufficiency checks
- Frozen address detection
- Rule engine integration
- Custom business logic support

### Administrative Controls
- Role-based permissions
- Emergency pause functionality
- Forced transfers for compliance
- Address freezing capabilities

## Security Considerations

1. **Role Management**: Carefully manage admin roles and permissions
2. **Pause Functionality**: Use pause for emergency situations only
3. **Forced Transfers**: Reserve for regulatory compliance only
4. **Engine Integration**: Validate external engines before integration
5. **Batch Operations**: Monitor gas usage for large batches

## Testing

The test suite covers:
- Token deployment and initialization
- Role-based access control
- Minting and burning operations
- Transfer restrictions and validations
- Pause and enforcement functionality
- Allowlist management
- Debt-specific features

Run tests with:
```bash
snforge test
```

## Legacy Implementation

This repository also includes a simple ERC20 implementation for backwards compatibility:

```bash
# Deploy the legacy ERC20 token
./scripts/deploy.sh
```

For full documentation of the legacy deployment, see the original sections below.

---

## License

This project is licensed under the Mozilla Public License 2.0 (MPL-2.0).

## Contributing

Contributions are welcome! Please ensure all tests pass and follow the established coding patterns.

## References

- [CMTAT Solidity v3.0.0](https://github.com/CMTA/CMTAT)
- [ERC3643-Cairo](https://github.com/Carbonable/ERC3643-Cairo)
- [ERC-1404](https://erc1404.org/)
- [OpenZeppelin Cairo Contracts](https://github.com/OpenZeppelin/cairo-contracts)

---

# Legacy ERC20 Implementation

The following sections document the original simple ERC20 token implementation.

## Features

- ✅ Standard ERC20 token implementation
- ✅ Built with OpenZeppelin Contracts for Cairo v0.17.0
- ✅ Compatible with Cairo 2.6.3 and Scarb 2.6.4
- ✅ Automated deployment script with block explorer URL
- ✅ Support for both Sepolia Testnet and Mainnet
- ✅ Initial supply of 1,000,000 tokens (18 decimals)
- ✅ Deployment details saved to JSON file

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Scarb** - Cairo package manager
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
   ```

2. **Starkli** - Starknet CLI tool
   ```bash
   curl https://get.starkli.sh | sh
   starkliup
   ```

3. **Starknet Account** - You need a funded account on either:
   - Sepolia Testnet (recommended for testing)
   - Mainnet (for production)

## Project Structure

```
cairo-cmtat/
├── Scarb.toml              # Project configuration
├── src/
│   └── lib.cairo           # ERC20 token contract
├── scripts/
│   └── deploy.sh           # Deployment script
└── README.md               # This file
```

## Quick Start

### 1. Build the Contract

```bash
scarb build
```

This will compile the Cairo contract and generate the contract class JSON files in the `target/dev/` directory.

### 2. Set Up Your Starknet Account

If you don't have a Starknet account yet, create one using Starkli:

```bash
# Create a new account
starkli account oz init ~/.starknet-accounts/account.json

# Deploy the account (you'll need to fund it first)
starkli account deploy ~/.starknet-accounts/account.json
```

### 3. Deploy the Token

Run the deployment script:

```bash
./scripts/deploy.sh
```

The script will:
1. Prompt you to select a network (Sepolia Testnet or Mainnet)
2. Ask for the recipient address (who will receive the initial token supply)
3. Request your account address and keystore path
4. Build, declare, and deploy the contract
5. Display the block explorer URL for your deployed contract
6. Save deployment details to `deployment.json`

## Deployment Script Details

The deployment script (`scripts/deploy.sh`) provides:

- **Interactive Network Selection**: Choose between Sepolia Testnet and Mainnet
- **Automated Build Process**: Compiles the contract before deployment
- **Class Declaration**: Declares the contract class on Starknet
- **Contract Deployment**: Deploys the contract with the specified recipient
- **Block Explorer Integration**: Returns the Voyager explorer URL for your contract
- **Deployment Logging**: Saves all deployment details to `deployment.json`

### Example Output

```
================================================
   CMTAT ERC20 Token Deployment Script
================================================

Select network:
1) Sepolia Testnet (default)
2) Mainnet
Enter choice [1-2] (default: 1): 1
Selected: Sepolia Testnet

Enter recipient address for initial token supply: 0x...
Enter your account address: 0x...
Enter path to your account keystore file: ~/.starknet-accounts/account.json

Step 1: Building the contract...
✓ Contract built successfully

Step 2: Declaring the contract class...
✓ Class hash: 0x...

Step 3: Deploying the contract...
✓ Contract deployed successfully!

================================================
   Deployment Successful!
================================================

Network: sepolia
Contract Address: 0x...
Class Hash: 0x...
Recipient: 0x...

Block Explorer URL:
https://sepolia.voyager.online/contract/0x...

Transaction Explorer:
https://sepolia.voyager.online/tx/0x...

================================================
Deployment details saved to deployment.json
```

## Token Details

- **Name**: CMTAT Token
- **Symbol**: CMTAT
- **Decimals**: 18 (standard)
- **Initial Supply**: 1,000,000 tokens (1,000,000 × 10^18 in smallest unit)

## Contract Interface

The contract implements the standard ERC20 interface:

- `name() -> felt252` - Returns the token name
- `symbol() -> felt252` - Returns the token symbol
- `decimals() -> u8` - Returns the number of decimals
- `total_supply() -> u256` - Returns the total token supply
- `balance_of(account: ContractAddress) -> u256` - Returns the balance of an account
- `allowance(owner: ContractAddress, spender: ContractAddress) -> u256` - Returns the allowance
- `transfer(recipient: ContractAddress, amount: u256) -> bool` - Transfers tokens
- `transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool` - Transfers tokens from
- `approve(spender: ContractAddress, amount: u256) -> bool` - Approves spending

## Interacting with Your Deployed Token

After deployment, you can interact with your token using Starkli:

### Check Token Balance

```bash
starkli call <CONTRACT_ADDRESS> balance_of <ACCOUNT_ADDRESS> --rpc <RPC_URL>
```

### Transfer Tokens

```bash
starkli invoke <CONTRACT_ADDRESS> transfer <RECIPIENT> <AMOUNT_LOW> <AMOUNT_HIGH> \
  --account <YOUR_ACCOUNT> \
  --keystore <KEYSTORE_PATH> \
  --rpc <RPC_URL>
```

### Approve Spending

```bash
starkli invoke <CONTRACT_ADDRESS> approve <SPENDER> <AMOUNT_LOW> <AMOUNT_HIGH> \
  --account <YOUR_ACCOUNT> \
  --keystore <KEYSTORE_PATH> \
  --rpc <RPC_URL>
```

## Block Explorer

Once deployed, you can view your contract on Voyager:

- **Sepolia Testnet**: https://sepolia.voyager.online/contract/YOUR_CONTRACT_ADDRESS
- **Mainnet**: https://voyager.online/contract/YOUR_CONTRACT_ADDRESS

The explorer allows you to:
- View all transactions
- Check token holders
- Read contract state
- Verify the contract code

## Troubleshooting

### Build Issues

If you encounter build errors:
```bash
# Clean the build directory
rm -rf target/

# Rebuild
scarb build
```

### Deployment Issues

If deployment fails:
1. Ensure your account has sufficient funds for gas fees
2. Verify your account address and keystore path are correct
3. Check that you're connected to the correct network
4. Make sure Starkli is properly installed and configured

### Account Funding

For Sepolia Testnet, you can get test ETH from:
- [Starknet Faucet](https://starknet-faucet.vercel.app/)
- [Alchemy Faucet](https://www.alchemy.com/faucets/starknet-sepolia)

## Security Considerations

- **Private Keys**: Never share your keystore files or private keys
- **Testing**: Always test on Sepolia Testnet before deploying to Mainnet
- **Audits**: Consider getting a professional audit for production deployments
- **Initial Supply**: Review the initial token supply before deployment
