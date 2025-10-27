// SPDX-License-Identifier: MPL-2.0
// Burn Module for CMTAT Cairo Implementation

use starknet::ContractAddress;
use starknet::get_caller_address;

#[starknet::interface]
pub trait IERC20Burn<TContractState> {
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    fn batch_burn(ref self: TContractState, accounts: Array<ContractAddress>, amounts: Array<u256>);
    fn forced_burn(ref self: TContractState, from: ContractAddress, amount: u256);
}

#[starknet::component]
pub mod ERC20BurnComponent {
    use super::{IERC20Burn, ContractAddress, get_caller_address};
    use crate::modules::access_control::{
        AccessControlComponent, Roles, only_burner, only_admin
    };
    use crate::modules::pause::{PauseComponent, when_not_deactivated};
    use crate::modules::enforcement::{
        EnforcementComponent, when_not_frozen, when_sufficient_active_balance
    };
    use crate::modules::erc20_base::ERC20BaseComponent;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Burn: Burn,
        ForcedBurn: ForcedBurn,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Burn {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub burner: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ForcedBurn {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub admin: ContractAddress,
        pub amount: u256,
    }

    pub mod Errors {
        pub const BURN_FROM_ZERO: felt252 = 'Burn: cannot burn from zero';
        pub const BURN_ARRAYS_LENGTH_MISMATCH: felt252 = 'Burn: arrays length mismatch';
    }

    #[embeddable_as(ERC20BurnImpl)]
    impl ERC20Burn<
        TContractState,
        +HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        impl Pause: PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        impl ERC20Base: ERC20BaseComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC20Burn<ComponentState<TContractState>> {
        fn burn(ref self: ComponentState<TContractState>, from: ContractAddress, amount: u256) {
            // Access control check
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_burner(@access_control);
            
            // Compliance checks
            assert(from.is_non_zero(), Errors::BURN_FROM_ZERO);
            
            let pause = get_dep_component!(@self, Pause);
            when_not_deactivated(pause);
            
            let enforcement = get_dep_component!(@self, Enforcement);
            when_not_frozen(enforcement, from);
            
            // Check active balance (considering frozen tokens)
            let erc20_base = get_dep_component!(@self, ERC20Base);
            let from_balance = erc20_base.balance_of(from);
            when_sufficient_active_balance(enforcement, from, from_balance, amount);
            
            // Perform burn
            let mut erc20_base = get_dep_component_mut!(ref self, ERC20Base);
            erc20_base._burn(from, amount);
            
            // Emit burn event
            let burner = get_caller_address();
            self.emit(Burn { from, burner, amount });
        }

        fn batch_burn(
            ref self: ComponentState<TContractState>,
            accounts: Array<ContractAddress>,
            amounts: Array<u256>
        ) {
            // Access control check
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_burner(@access_control);
            
            // Validate arrays
            assert(accounts.len() == amounts.len(), Errors::BURN_ARRAYS_LENGTH_MISMATCH);
            
            // Compliance checks
            let pause = get_dep_component!(@self, Pause);
            when_not_deactivated(pause);
            
            let enforcement = get_dep_component!(@self, Enforcement);
            let erc20_base = get_dep_component!(@self, ERC20Base);
            let burner = get_caller_address();
            
            // Process each burn
            let mut i = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                
                let from = *accounts.at(i);
                let amount = *amounts.at(i);
                
                // Individual compliance checks
                assert(from.is_non_zero(), Errors::BURN_FROM_ZERO);
                when_not_frozen(enforcement, from);
                
                // Check active balance
                let from_balance = erc20_base.balance_of(from);
                when_sufficient_active_balance(enforcement, from, from_balance, amount);
                
                // Perform burn
                let mut erc20_base = get_dep_component_mut!(ref self, ERC20Base);
                erc20_base._burn(from, amount);
                
                // Emit event
                self.emit(Burn { from, burner, amount });
                
                i += 1;
            };
        }

        fn forced_burn(ref self: ComponentState<TContractState>, from: ContractAddress, amount: u256) {
            // Access control check - only admin can force burn
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);
            
            // Basic validation
            assert(from.is_non_zero(), Errors::BURN_FROM_ZERO);
            
            // Forced burns respect deactivation but can bypass other restrictions
            let pause = get_dep_component!(@self, Pause);
            when_not_deactivated(pause);
            
            // Unfreeze tokens if necessary for forced burn
            let mut enforcement = get_dep_component_mut!(ref self, Enforcement);
            enforcement.unfreeze_for_transfer(from, amount);
            
            // Perform burn
            let mut erc20_base = get_dep_component_mut!(ref self, ERC20Base);
            erc20_base._burn(from, amount);
            
            // Emit forced burn event
            let admin = get_caller_address();
            self.emit(ForcedBurn { from, admin, amount });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            // No initialization needed
        }
    }
}