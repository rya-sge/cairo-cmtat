// SPDX-License-Identifier: MPL-2.0
// Pause Module for CMTAT Cairo Implementation

use starknet::ContractAddress;
use starknet::get_caller_address;

#[starknet::interface]
pub trait IPausable<TContractState> {
    fn is_paused(self: @TContractState) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn is_deactivated(self: @TContractState) -> bool;
    fn deactivate_contract(ref self: TContractState);
}

#[starknet::component]
pub mod PauseComponent {
    use super::{IPausable, ContractAddress, get_caller_address};
    use crate::modules::access_control::{
        AccessControlComponent, Roles, only_pauser, only_admin
    };

    #[storage]
    struct Storage {
        paused: bool,
        deactivated: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Paused: Paused,
        Unpaused: Unpaused,
        Deactivated: Deactivated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Paused {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unpaused {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deactivated {
        #[key]
        pub account: ContractAddress,
    }

    pub mod Errors {
        pub const PAUSABLE_PAUSED: felt252 = 'Pausable: contract paused';
        pub const PAUSABLE_NOT_PAUSED: felt252 = 'Pausable: contract not paused';
        pub const PAUSABLE_DEACTIVATED: felt252 = 'Pausable: contract deactivated';
        pub const PAUSABLE_MUST_BE_PAUSED: felt252 = 'Pausable: must be paused first';
    }

    #[embeddable_as(PausableImpl)]
    impl Pausable<
        TContractState,
        +HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>
    > of IPausable<ComponentState<TContractState>> {
        fn is_paused(self: @ComponentState<TContractState>) -> bool {
            self.paused.read()
        }

        fn pause(ref self: ComponentState<TContractState>) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_pauser(@access_control);
            
            assert(!self.paused.read(), Errors::PAUSABLE_PAUSED);
            assert(!self.deactivated.read(), Errors::PAUSABLE_DEACTIVATED);
            
            self.paused.write(true);
            self.emit(Paused { account: get_caller_address() });
        }

        fn unpause(ref self: ComponentState<TContractState>) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_pauser(@access_control);
            
            assert(self.paused.read(), Errors::PAUSABLE_NOT_PAUSED);
            assert(!self.deactivated.read(), Errors::PAUSABLE_DEACTIVATED);
            
            self.paused.write(false);
            self.emit(Unpaused { account: get_caller_address() });
        }

        fn is_deactivated(self: @ComponentState<TContractState>) -> bool {
            self.deactivated.read()
        }

        fn deactivate_contract(ref self: ComponentState<TContractState>) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);
            
            // Contract must be paused before deactivation
            assert(self.paused.read(), Errors::PAUSABLE_MUST_BE_PAUSED);
            assert(!self.deactivated.read(), Errors::PAUSABLE_DEACTIVATED);
            
            self.deactivated.write(true);
            self.emit(Deactivated { account: get_caller_address() });
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            self.paused.write(false);
            self.deactivated.write(false);
        }

        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.paused.read(), Errors::PAUSABLE_PAUSED);
        }

        fn assert_not_deactivated(self: @ComponentState<TContractState>) {
            assert(!self.deactivated.read(), Errors::PAUSABLE_DEACTIVATED);
        }

        fn assert_active(self: @ComponentState<TContractState>) {
            self.assert_not_paused();
            self.assert_not_deactivated();
        }
    }
}

/// Helper functions for pause checks
pub fn when_not_paused(pause: @PauseComponent::ComponentState<impl TContractState>) {
    pause.assert_not_paused();
}

pub fn when_not_deactivated(pause: @PauseComponent::ComponentState<impl TContractState>) {
    pause.assert_not_deactivated();
}

pub fn when_active(pause: @PauseComponent::ComponentState<impl TContractState>) {
    pause.assert_active();
}