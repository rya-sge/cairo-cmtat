// SPDX-License-Identifier: MPL-2.0
// ERC20 Base Module for CMTAT Cairo Implementation

use starknet::ContractAddress;
use starknet::get_caller_address;

#[starknet::interface]
pub trait IERC20Base<TContractState> {
    // ERC20 Standard
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    
    // CMTAT Extensions
    fn set_name(ref self: TContractState, new_name: ByteArray);
    fn set_symbol(ref self: TContractState, new_symbol: ByteArray);
    fn batch_transfer(ref self: TContractState, recipients: Array<ContractAddress>, amounts: Array<u256>) -> bool;
    fn forced_transfer(ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256) -> bool;
}

#[starknet::component]
pub mod ERC20BaseComponent {
    use super::{IERC20Base, ContractAddress, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use crate::modules::access_control::{
        AccessControlComponent, Roles, only_admin, only_minter
    };
    use crate::modules::pause::{PauseComponent, when_not_paused, when_active};
    use crate::modules::enforcement::{
        EnforcementComponent, when_not_frozen, when_sufficient_active_balance
    };

    #[storage]
    struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        NameChanged: NameChanged,
        SymbolChanged: SymbolChanged,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NameChanged {
        pub old_name: ByteArray,
        pub new_name: ByteArray,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SymbolChanged {
        pub old_symbol: ByteArray,
        pub new_symbol: ByteArray,
    }

    pub mod Errors {
        pub const ERC20_TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        pub const ERC20_TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        pub const ERC20_APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
        pub const ERC20_APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        pub const ERC20_INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';
        pub const ERC20_INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
        pub const ERC20_ARRAYS_LENGTH_MISMATCH: felt252 = 'ERC20: arrays length mismatch';
    }

    #[embeddable_as(ERC20BaseImpl)]
    impl ERC20Base<
        TContractState,
        +HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        impl Pause: PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC20Base<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ComponentState<TContractState>) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256) -> bool {
            let from = get_caller_address();
            self._transfer(from, to, amount);
            true
        }

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
            let spender = get_caller_address();
            
            // Check and update allowance
            let current_allowance = self.allowances.read((from, spender));
            assert(current_allowance >= amount, Errors::ERC20_INSUFFICIENT_ALLOWANCE);
            
            // Transfer tokens
            self._transfer_from(spender, from, to, amount);
            
            // Update allowance
            let new_allowance = current_allowance - amount;
            self.allowances.write((from, spender), new_allowance);
            self.emit(Approval { owner: from, spender, value: new_allowance });
            
            true
        }

        fn approve(ref self: ComponentState<TContractState>, spender: ContractAddress, amount: u256) -> bool {
            let owner = get_caller_address();
            self._approve(owner, spender, amount);
            true
        }

        fn set_name(ref self: ComponentState<TContractState>, new_name: ByteArray) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);
            
            let old_name = self.name.read();
            self.name.write(new_name.clone());
            self.emit(NameChanged { old_name, new_name });
        }

        fn set_symbol(ref self: ComponentState<TContractState>, new_symbol: ByteArray) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);
            
            let old_symbol = self.symbol.read();
            self.symbol.write(new_symbol.clone());
            self.emit(SymbolChanged { old_symbol, new_symbol });
        }

        fn batch_transfer(
            ref self: ComponentState<TContractState>,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_minter(@access_control);
            
            assert(recipients.len() == amounts.len(), Errors::ERC20_ARRAYS_LENGTH_MISMATCH);
            
            let from = get_caller_address();
            let mut i = 0;
            
            loop {
                if i >= recipients.len() {
                    break;
                }
                
                let to = *recipients.at(i);
                let amount = *amounts.at(i);
                
                self._transfer(from, to, amount);
                
                i += 1;
            };
            
            true
        }

        fn forced_transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);
            
            // Forced transfers can unfreeze tokens if needed
            let mut enforcement = get_dep_component_mut!(ref self, Enforcement);
            enforcement.unfreeze_for_transfer(from, amount);
            
            self._forced_transfer(from, to, amount);
            true
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        impl Pause: PauseComponent::HasComponent<TContractState>,
        impl Enforcement: EnforcementComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            name: ByteArray,
            symbol: ByteArray,
            decimals: u8,
            initial_supply: u256,
            recipient: ContractAddress
        ) {
            self.name.write(name);
            self.symbol.write(symbol);
            self.decimals.write(decimals);
            
            if initial_supply > 0 {
                self._mint(recipient, initial_supply);
            }
        }

        fn _transfer(ref self: ComponentState<TContractState>, from: ContractAddress, to: ContractAddress, amount: u256) {
            // Basic validations
            assert(from.is_non_zero(), Errors::ERC20_TRANSFER_FROM_ZERO);
            assert(to.is_non_zero(), Errors::ERC20_TRANSFER_TO_ZERO);
            
            // Compliance checks
            let pause = get_dep_component!(@self, Pause);
            when_active(pause);
            
            let enforcement = get_dep_component!(@self, Enforcement);
            when_not_frozen(enforcement, from);
            when_not_frozen(enforcement, to);
            
            // Check active balance (considering frozen tokens)
            let from_balance = self.balances.read(from);
            when_sufficient_active_balance(enforcement, from, from_balance, amount);
            
            // Perform transfer
            self._update(from, to, amount);
        }

        fn _transfer_from(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            // Basic validations
            assert(from.is_non_zero(), Errors::ERC20_TRANSFER_FROM_ZERO);
            assert(to.is_non_zero(), Errors::ERC20_TRANSFER_TO_ZERO);
            
            // Compliance checks
            let pause = get_dep_component!(@self, Pause);
            when_active(pause);
            
            let enforcement = get_dep_component!(@self, Enforcement);
            when_not_frozen(enforcement, spender);
            when_not_frozen(enforcement, from);
            when_not_frozen(enforcement, to);
            
            // Check active balance
            let from_balance = self.balances.read(from);
            when_sufficient_active_balance(enforcement, from, from_balance, amount);
            
            // Perform transfer
            self._update(from, to, amount);
        }

        fn _forced_transfer(ref self: ComponentState<TContractState>, from: ContractAddress, to: ContractAddress, amount: u256) {
            // Forced transfers bypass most restrictions but respect deactivation
            assert(from.is_non_zero(), Errors::ERC20_TRANSFER_FROM_ZERO);
            assert(to.is_non_zero(), Errors::ERC20_TRANSFER_TO_ZERO);
            
            let pause = get_dep_component!(@self, Pause);
            pause.assert_not_deactivated();
            
            self._update(from, to, amount);
        }

        fn _approve(ref self: ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            assert(owner.is_non_zero(), Errors::ERC20_APPROVE_FROM_ZERO);
            assert(spender.is_non_zero(), Errors::ERC20_APPROVE_TO_ZERO);
            
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _mint(ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256) {
            assert(to.is_non_zero(), Errors::ERC20_TRANSFER_TO_ZERO);
            
            self._update(starknet::contract_address_const::<0>(), to, amount);
        }

        fn _burn(ref self: ComponentState<TContractState>, from: ContractAddress, amount: u256) {
            assert(from.is_non_zero(), Errors::ERC20_TRANSFER_FROM_ZERO);
            
            self._update(from, starknet::contract_address_const::<0>(), amount);
        }

        fn _update(ref self: ComponentState<TContractState>, from: ContractAddress, to: ContractAddress, amount: u256) {
            let zero_address = starknet::contract_address_const::<0>();
            
            if from == zero_address {
                // Minting
                let new_total_supply = self.total_supply.read() + amount;
                self.total_supply.write(new_total_supply);
            } else {
                // Burning or transfer
                let from_balance = self.balances.read(from);
                assert(from_balance >= amount, Errors::ERC20_INSUFFICIENT_BALANCE);
                self.balances.write(from, from_balance - amount);
            }
            
            if to == zero_address {
                // Burning
                let new_total_supply = self.total_supply.read() - amount;
                self.total_supply.write(new_total_supply);
            } else {
                // Minting or transfer
                let to_balance = self.balances.read(to);
                self.balances.write(to, to_balance + amount);
            }
            
            self.emit(Transfer { from, to, value: amount });
        }
    }
}