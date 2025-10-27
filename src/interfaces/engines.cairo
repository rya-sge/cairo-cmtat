// SPDX-License-Identifier: MPL-2.0
// Engine Interfaces for CMTAT Cairo Implementation

use starknet::ContractAddress;

/// Rule Engine Interface - ERC-1404 compatible transfer restrictions
#[starknet::interface]
pub trait IRuleEngine<TContractState> {
    /// Check if a transfer is valid according to compliance rules
    /// Returns true if transfer is allowed, false otherwise
    fn can_transfer(self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
    
    /// Extended transfer check including spender verification (for transferFrom)
    fn can_transfer_from(self: @TContractState, spender: ContractAddress, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
    
    /// Get transfer restriction code (ERC-1404 compliance)
    /// Returns 0 if transfer is allowed, error code otherwise
    fn detect_transfer_restriction(self: @TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> u8;
    
    /// Get human-readable message for restriction code
    fn message_for_transfer_restriction(self: @TContractState, restriction_code: u8) -> ByteArray;
    
    /// Called after successful transfer to update rule engine state
    fn transferred(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256);
    
    /// Extended transferred call including spender information
    fn transferred_from(ref self: TContractState, spender: ContractAddress, from: ContractAddress, to: ContractAddress, amount: u256);
}

/// Snapshot Engine Interface - For on-chain balance snapshots
#[starknet::interface]
pub trait ISnapshotEngine<TContractState> {
    /// Record balance snapshot before transfer occurs
    fn operate_on_transfer(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        balance_from: u256,
        balance_to: u256,
        total_supply: u256
    );
    
    /// Take a snapshot of current balances
    fn snapshot(ref self: TContractState) -> u256;
    
    /// Get balance at specific snapshot
    fn balance_of_at(self: @TContractState, account: ContractAddress, snapshot_id: u256) -> u256;
    
    /// Get total supply at specific snapshot
    fn total_supply_at(self: @TContractState, snapshot_id: u256) -> u256;
    
    /// Get current snapshot ID
    fn current_snapshot_id(self: @TContractState) -> u256;
}

/// Document Engine Interface - ERC-1643 compatible document management
#[starknet::interface]
pub trait IDocumentEngine<TContractState> {
    /// Document structure
    #[derive(Drop, Serde)]
    struct Document {
        name: ByteArray,
        uri: ByteArray,
        document_hash: felt252,
        last_modified: u64,
    }
    
    /// Get document by name
    fn get_document(self: @TContractState, name: ByteArray) -> Document;
    
    /// Get all document names
    fn get_all_documents(self: @TContractState) -> Array<ByteArray>;
    
    /// Set or update a document
    fn set_document(ref self: TContractState, name: ByteArray, uri: ByteArray, document_hash: felt252);
    
    /// Remove a document
    fn remove_document(ref self: TContractState, name: ByteArray);
}

/// Debt Engine Interface - For debt-specific information and credit events
#[starknet::interface]
pub trait IDebtEngine<TContractState> {
    /// Debt information structure
    #[derive(Drop, Serde)]
    struct DebtInfo {
        isin: ByteArray,
        maturity_date: u64,
        interest_rate: u256,
        par_value: u256,
        currency: ByteArray,
        issuer_name: ByteArray,
    }
    
    /// Credit event structure
    #[derive(Drop, Serde)]
    struct CreditEvent {
        event_type: ByteArray,
        occurred: bool,
        occurrence_date: u64,
        description: ByteArray,
    }
    
    /// Get comprehensive debt information
    fn get_debt_info(self: @TContractState) -> DebtInfo;
    
    /// Get credit events
    fn get_credit_events(self: @TContractState) -> Array<CreditEvent>;
    
    /// Set debt information
    fn set_debt_info(ref self: TContractState, debt_info: DebtInfo);
    
    /// Add or update credit event
    fn set_credit_event(ref self: TContractState, event_type: ByteArray, occurred: bool, description: ByteArray);
}

/// Authorization Engine Interface - For external access control validation
#[starknet::interface]
pub trait IAuthorizationEngine<TContractState> {
    /// Check if an address has permission for a specific operation
    fn has_permission(self: @TContractState, account: ContractAddress, operation: felt252) -> bool;
    
    /// Grant permission for an operation
    fn grant_permission(ref self: TContractState, account: ContractAddress, operation: felt252);
    
    /// Revoke permission for an operation
    fn revoke_permission(ref self: TContractState, account: ContractAddress, operation: felt252);
    
    /// Get all permissions for an account
    fn get_permissions(self: @TContractState, account: ContractAddress) -> Array<felt252>;
}

/// Standard restriction codes for ERC-1404 compliance
pub mod RestrictionCodes {
    pub const TRANSFER_OK: u8 = 0;
    pub const TRANSFER_REJECTED_PAUSED: u8 = 1;
    pub const TRANSFER_REJECTED_FROM_FROZEN: u8 = 2;
    pub const TRANSFER_REJECTED_TO_FROZEN: u8 = 3;
    pub const TRANSFER_REJECTED_SPENDER_FROZEN: u8 = 4;
    pub const TRANSFER_REJECTED_INSUFFICIENT_ACTIVE_BALANCE: u8 = 5;
    pub const TRANSFER_REJECTED_NOT_ALLOWLISTED_FROM: u8 = 6;
    pub const TRANSFER_REJECTED_NOT_ALLOWLISTED_TO: u8 = 7;
    pub const TRANSFER_REJECTED_RULE_ENGINE: u8 = 8;
    pub const TRANSFER_REJECTED_DEACTIVATED: u8 = 9;
}