// SPDX-License-Identifier: MPL-2.0
// Enforcement Module for CMTAT Cairo Implementation
// Handles address freezing and partial token freezing

use starknet::ContractAddress;
use starknet::get_caller_address;

#[starknet::interface]
pub trait IEnforcement<TContractState> {
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
    fn freeze_address(ref self: TContractState, account: ContractAddress);
    fn unfreeze_address(ref self: TContractState, account: ContractAddress);
    fn batch_freeze_addresses(ref self: TContractState, accounts: Array<ContractAddress>, freeze_states: Array<bool>);
    
    // Partial token freezing (ERC20 Enforcement)
    fn get_frozen_tokens(self: @TContractState, account: ContractAddress) -> u256;
    fn freeze_partial_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn unfreeze_partial_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn get_active_balance(self: @TContractState, account: ContractAddress, total_balance: u256) -> u256;
}

#[starknet::component]
pub mod EnforcementComponent {
    use super::{IEnforcement, ContractAddress, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use crate::modules::access_control::{
        AccessControlComponent, Roles, only_enforcer
    };

    #[storage]
    struct Storage {
        frozen_addresses: Map<ContractAddress, bool>,
        frozen_tokens: Map<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AddressFrozen {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub enforcer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AddressUnfrozen {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub enforcer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensFrozen {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub enforcer: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokensUnfrozen {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub enforcer: ContractAddress,
        pub amount: u256,
    }

    pub mod Errors {
        pub const ENFORCEMENT_FROZEN_ADDRESS: felt252 = 'Enforcement: address frozen';
        pub const ENFORCEMENT_INSUFFICIENT_BALANCE: felt252 = 'Enforcement: insufficient balance';
        pub const ENFORCEMENT_INSUFFICIENT_FROZEN: felt252 = 'Enforcement: insufficient frozen';
        pub const ENFORCEMENT_ARRAYS_LENGTH_MISMATCH: felt252 = 'Enforcement: arrays length mismatch';
    }

    #[embeddable_as(EnforcementImpl)]
    impl Enforcement<
        TContractState,
        +HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>
    > of IEnforcement<ComponentState<TContractState>> {
        fn is_frozen(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            self.frozen_addresses.read(account)
        }

        fn freeze_address(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_enforcer(@access_control);
            
            self.frozen_addresses.write(account, true);
            self.emit(AddressFrozen { account, enforcer: get_caller_address() });
        }

        fn unfreeze_address(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_enforcer(@access_control);
            
            self.frozen_addresses.write(account, false);
            self.emit(AddressUnfrozen { account, enforcer: get_caller_address() });
        }

        fn batch_freeze_addresses(
            ref self: ComponentState<TContractState>,
            accounts: Array<ContractAddress>,
            freeze_states: Array<bool>
        ) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_enforcer(@access_control);
            
            assert(accounts.len() == freeze_states.len(), Errors::ENFORCEMENT_ARRAYS_LENGTH_MISMATCH);
            
            let mut i = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                
                let account = *accounts.at(i);
                let freeze_state = *freeze_states.at(i);
                
                self.frozen_addresses.write(account, freeze_state);
                
                if freeze_state {
                    self.emit(AddressFrozen { account, enforcer: get_caller_address() });
                } else {
                    self.emit(AddressUnfrozen { account, enforcer: get_caller_address() });
                }
                
                i += 1;
            };
        }

        fn get_frozen_tokens(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.frozen_tokens.read(account)
        }

        fn freeze_partial_tokens(ref self: ComponentState<TContractState>, account: ContractAddress, amount: u256) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_enforcer(@access_control);
            
            let current_frozen = self.frozen_tokens.read(account);
            self.frozen_tokens.write(account, current_frozen + amount);
            
            self.emit(TokensFrozen { account, enforcer: get_caller_address(), amount });
        }

        fn unfreeze_partial_tokens(ref self: ComponentState<TContractState>, account: ContractAddress, amount: u256) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_enforcer(@access_control);
            
            let current_frozen = self.frozen_tokens.read(account);
            assert(current_frozen >= amount, Errors::ENFORCEMENT_INSUFFICIENT_FROZEN);
            
            self.frozen_tokens.write(account, current_frozen - amount);
            
            self.emit(TokensUnfrozen { account, enforcer: get_caller_address(), amount });
        }

        fn get_active_balance(self: @ComponentState<TContractState>, account: ContractAddress, total_balance: u256) -> u256 {
            let frozen = self.frozen_tokens.read(account);
            if frozen >= total_balance {
                0
            } else {
                total_balance - frozen
            }
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            // No initialization needed
        }

        fn assert_not_frozen(self: @ComponentState<TContractState>, account: ContractAddress) {
            assert(!self.frozen_addresses.read(account), Errors::ENFORCEMENT_FROZEN_ADDRESS);
        }

        fn assert_sufficient_active_balance(
            self: @ComponentState<TContractState>,
            account: ContractAddress,
            total_balance: u256,
            required_amount: u256
        ) {
            let active_balance = self.get_active_balance(account, total_balance);
            assert(active_balance >= required_amount, Errors::ENFORCEMENT_INSUFFICIENT_BALANCE);
        }

        fn unfreeze_for_transfer(ref self: ComponentState<TContractState>, account: ContractAddress, amount: u256) {
            let frozen_amount = self.frozen_tokens.read(account);
            if frozen_amount > 0 {
                let to_unfreeze = if frozen_amount > amount { amount } else { frozen_amount };
                self.frozen_tokens.write(account, frozen_amount - to_unfreeze);
                self.emit(TokensUnfrozen { account, enforcer: get_caller_address(), amount: to_unfreeze });
            }
        }
    }
}

/// Helper functions for enforcement checks
pub fn when_not_frozen(enforcement: @EnforcementComponent::ComponentState<impl TContractState>, account: ContractAddress) {
    enforcement.assert_not_frozen(account);
}

pub fn when_sufficient_active_balance(
    enforcement: @EnforcementComponent::ComponentState<impl TContractState>,
    account: ContractAddress,
    total_balance: u256,
    required_amount: u256
) {
    enforcement.assert_sufficient_active_balance(account, total_balance, required_amount);
}