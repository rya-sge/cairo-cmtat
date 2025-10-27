// SPDX-License-Identifier: MPL-2.0
// Access Control Module for CMTAT Cairo Implementation
// Based on OpenZeppelin AccessControl with CMTAT-specific roles

use starknet::ContractAddress;
use starknet::get_caller_address;

/// Role-based access control interface
#[starknet::interface]
pub trait IAccessControl<TContractState> {
    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TContractState, role: felt252) -> felt252;
    fn grant_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TContractState, role: felt252, account: ContractAddress);
}

/// CMTAT-specific role constants
pub mod Roles {
    pub const DEFAULT_ADMIN_ROLE: felt252 = 0;
    pub const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
    pub const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");
    pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
    pub const ENFORCER_ROLE: felt252 = selector!("ENFORCER_ROLE");
    pub const ERC20_ENFORCER_ROLE: felt252 = selector!("ERC20_ENFORCER_ROLE");
    pub const SNAPSHOOTER_ROLE: felt252 = selector!("SNAPSHOOTER_ROLE");
    pub const DOCUMENT_ROLE: felt252 = selector!("DOCUMENT_ROLE");
    pub const EXTRA_INFORMATION_ROLE: felt252 = selector!("EXTRA_INFORMATION_ROLE");
    pub const ALLOWLIST_ROLE: felt252 = selector!("ALLOWLIST_ROLE");
    pub const DEBT_ROLE: felt252 = selector!("DEBT_ROLE");
    pub const RULE_ENGINE_ROLE: felt252 = selector!("RULE_ENGINE_ROLE");
}

#[starknet::component]
pub mod AccessControlComponent {
    use super::{IAccessControl, Roles, ContractAddress, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};

    #[storage]
    struct Storage {
        roles: Map<(felt252, ContractAddress), bool>,
        role_admins: Map<felt252, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
        RoleAdminChanged: RoleAdminChanged,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleGranted {
        #[key]
        pub role: felt252,
        #[key]
        pub account: ContractAddress,
        #[key]
        pub sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleRevoked {
        #[key]
        pub role: felt252,
        #[key]
        pub account: ContractAddress,
        #[key]
        pub sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoleAdminChanged {
        #[key]
        pub role: felt252,
        #[key]
        pub previous_admin_role: felt252,
        #[key]
        pub new_admin_role: felt252,
    }

    pub mod Errors {
        pub const ACCESS_CONTROL_UNAUTHORIZED: felt252 = 'AccessControl: unauthorized';
        pub const ACCESS_CONTROL_ONLY_ADMIN: felt252 = 'AccessControl: only admin';
        pub const ACCESS_CONTROL_INVALID_ACCOUNT: felt252 = 'AccessControl: invalid account';
    }

    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
        TContractState, +HasComponent<TContractState>
    > of IAccessControl<ComponentState<TContractState>> {
        fn has_role(self: @ComponentState<TContractState>, role: felt252, account: ContractAddress) -> bool {
            // Admin has all roles by default (CMTAT behavior)
            if self.roles.read((Roles::DEFAULT_ADMIN_ROLE, account)) {
                return true;
            }
            self.roles.read((role, account))
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.role_admins.read(role)
        }

        fn grant_role(ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress) {
            let caller = get_caller_address();
            assert(self.has_role(self.get_role_admin(role), caller), Errors::ACCESS_CONTROL_ONLY_ADMIN);
            self._grant_role(role, account);
        }

        fn revoke_role(ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress) {
            let caller = get_caller_address();
            assert(self.has_role(self.get_role_admin(role), caller), Errors::ACCESS_CONTROL_ONLY_ADMIN);
            self._revoke_role(role, account);
        }

        fn renounce_role(ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress) {
            let caller = get_caller_address();
            assert(caller == account, Errors::ACCESS_CONTROL_INVALID_ACCOUNT);
            self._revoke_role(role, account);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            self._grant_role(Roles::DEFAULT_ADMIN_ROLE, admin);
        }

        fn _grant_role(ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress) {
            if !self.has_role(role, account) {
                self.roles.write((role, account), true);
                self.emit(RoleGranted { role, account, sender: get_caller_address() });
            }
        }

        fn _revoke_role(ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress) {
            if self.has_role(role, account) {
                self.roles.write((role, account), false);
                self.emit(RoleRevoked { role, account, sender: get_caller_address() });
            }
        }

        fn _set_role_admin(ref self: ComponentState<TContractState>, role: felt252, admin_role: felt252) {
            let previous_admin_role = self.get_role_admin(role);
            self.role_admins.write(role, admin_role);
            self.emit(RoleAdminChanged { role, previous_admin_role, new_admin_role: admin_role });
        }

        fn assert_only_role(self: @ComponentState<TContractState>, role: felt252) {
            let caller = get_caller_address();
            assert(self.has_role(role, caller), Errors::ACCESS_CONTROL_UNAUTHORIZED);
        }
    }
}

/// Modifier-like functions for role checking
pub fn only_role(access_control: @AccessControlComponent::ComponentState<impl TContractState>, role: felt252) {
    access_control.assert_only_role(role);
}

pub fn only_admin(access_control: @AccessControlComponent::ComponentState<impl TContractState>) {
    access_control.assert_only_role(Roles::DEFAULT_ADMIN_ROLE);
}

pub fn only_minter(access_control: @AccessControlComponent::ComponentState<impl TContractState>) {
    access_control.assert_only_role(Roles::MINTER_ROLE);
}

pub fn only_burner(access_control: @AccessControlComponent::ComponentState<impl TContractState>) {
    access_control.assert_only_role(Roles::BURNER_ROLE);
}

pub fn only_pauser(access_control: @AccessControlComponent::ComponentState<impl TContractState>) {
    access_control.assert_only_role(Roles::PAUSER_ROLE);
}

pub fn only_enforcer(access_control: @AccessControlComponent::ComponentState<impl TContractState>) {
    access_control.assert_only_role(Roles::ENFORCER_ROLE);
}