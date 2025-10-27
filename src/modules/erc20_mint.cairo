// SPDX-License-Identifier: MPL-2.0
// Mint Module for CMTAT Cairo Implementation

use starknet::ContractAddress;
use starknet::get_caller_address;

#[starknet::interface]
pub trait IERC20Mint<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn batch_mint(ref self: TContractState, accounts: Array<ContractAddress>, amounts: Array<u256>);
}

#[starknet::component]
pub mod ERC20MintComponent {
    use super::{IERC20Mint, ContractAddress, get_caller_address};
    use crate::modules::access_control::{
        AccessControlComponent, Roles, only_minter
    };
    use crate::modules::pause::{PauseComponent, when_not_deactivated};
    use crate::modules::enforcement::{EnforcementComponent, when_not_frozen};
    use crate::modules::erc20_base::ERC20BaseComponent;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Mint: Mint,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Mint {
        #[key]
        pub to: ContractAddress,
        #[key]
        pub minter: ContractAddress,
        pub amount: u256,
    }

    pub mod Errors {
        pub const MINT_TO_ZERO: felt252 = 'Mint: cannot mint to zero';
        pub const MINT_ARRAYS_LENGTH_MISMATCH: felt252 = 'Mint: arrays length mismatch';
    }

    #[embeddable_as(ERC20MintImpl)]
    impl ERC20Mint<
        TContractState,
        +HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        impl Pause: PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        impl ERC20Base: ERC20BaseComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC20Mint<ComponentState<TContractState>> {
        fn mint(ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256) {
            // Access control check
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_minter(@access_control);
            
            // Compliance checks
            assert(to.is_non_zero(), Errors::MINT_TO_ZERO);
            
            let pause = get_dep_component!(@self, Pause);
            when_not_deactivated(pause);
            
            let enforcement = get_dep_component!(@self, Enforcement);
            when_not_frozen(enforcement, to);
            
            // Perform mint
            let mut erc20_base = get_dep_component_mut!(ref self, ERC20Base);
            erc20_base._mint(to, amount);
            
            // Emit mint event
            let minter = get_caller_address();
            self.emit(Mint { to, minter, amount });
        }

        fn batch_mint(
            ref self: ComponentState<TContractState>,
            accounts: Array<ContractAddress>,
            amounts: Array<u256>
        ) {
            // Access control check
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_minter(@access_control);
            
            // Validate arrays
            assert(accounts.len() == amounts.len(), Errors::MINT_ARRAYS_LENGTH_MISMATCH);
            
            // Compliance checks
            let pause = get_dep_component!(@self, Pause);
            when_not_deactivated(pause);
            
            let enforcement = get_dep_component!(@self, Enforcement);
            let minter = get_caller_address();
            
            // Process each mint
            let mut i = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                
                let to = *accounts.at(i);
                let amount = *amounts.at(i);
                
                // Individual compliance checks
                assert(to.is_non_zero(), Errors::MINT_TO_ZERO);
                when_not_frozen(enforcement, to);
                
                // Perform mint
                let mut erc20_base = get_dep_component_mut!(ref self, ERC20Base);
                erc20_base._mint(to, amount);
                
                // Emit event
                self.emit(Mint { to, minter, amount });
                
                i += 1;
            };
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