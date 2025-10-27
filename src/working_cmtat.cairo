// SPDX-License-Identifier: MPL-2.0
// Working CMTAT Implementation compatible with Cairo 2.6.3

#[starknet::contract]
mod WorkingCMTAT {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::security::pausable::PausableComponent;
    use starknet::{ContractAddress, get_caller_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    // Mixin implementations
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableMixinImpl = PausableComponent::PausableMixinImpl<ContractState>;

    // Internal implementations
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;

    // Constants for CMTAT roles
    const MINTER_ROLE: felt252 = 'MINTER';
    const BURNER_ROLE: felt252 = 'BURNER';
    const ENFORCER_ROLE: felt252 = 'ENFORCER';

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        // CMTAT specific storage
        terms: felt252,
        flag: felt252,
        frozen_addresses: LegacyMap<ContractAddress, bool>,
        frozen_tokens: LegacyMap<ContractAddress, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        // CMTAT specific events
        TermsSet: TermsSet,
        FlagSet: FlagSet,
        AddressFrozen: AddressFrozen,
        AddressUnfrozen: AddressUnfrozen,
        TokensFrozen: TokensFrozen,
        TokensUnfrozen: TokensUnfrozen,
    }

    #[derive(Drop, starknet::Event)]
    struct TermsSet {
        #[key]
        pub previous_terms: felt252,
        pub new_terms: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct FlagSet {
        #[key]
        pub previous_flag: felt252,
        pub new_flag: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressFrozen {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressUnfrozen {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensFrozen {
        #[key]
        pub account: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensUnfrozen {
        #[key]
        pub account: ContractAddress,
        pub amount: u256,
    }

    mod Errors {
        const ADDRESS_FROZEN: felt252 = 'CMTAT: address frozen';
        const INSUFFICIENT_ACTIVE_BALANCE: felt252 = 'CMTAT: insufficient active balance';
        const CALLER_NOT_ADMIN: felt252 = 'CMTAT: caller not admin';
        const CALLER_NOT_MINTER: felt252 = 'CMTAT: caller not minter';
        const CALLER_NOT_BURNER: felt252 = 'CMTAT: caller not burner';
        const CALLER_NOT_ENFORCER: felt252 = 'CMTAT: caller not enforcer';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
        terms: felt252,
        flag: felt252
    ) {
        // Initialize components
        self.erc20.initializer(name, symbol);
        self.access_control.initializer();
        self.pausable.initializer();

        // Grant roles to admin
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, admin);
        self.access_control._grant_role(MINTER_ROLE, admin);
        self.access_control._grant_role(BURNER_ROLE, admin);
        self.access_control._grant_role(ENFORCER_ROLE, admin);

        // Set CMTAT metadata
        self.terms.write(terms);
        self.flag.write(flag);

        // Mint initial supply
        if initial_supply > 0 {
            self.erc20._mint(recipient, initial_supply);
        }
    }

    #[abi(embed_v0)]
    impl CMTATImpl of super::ICMTAT<ContractState> {
        fn terms(self: @ContractState) -> felt252 {
            self.terms.read()
        }

        fn set_terms(ref self: ContractState, new_terms: felt252) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            let previous_terms = self.terms.read();
            self.terms.write(new_terms);
            self.emit(TermsSet { previous_terms, new_terms });
        }

        fn flag(self: @ContractState) -> felt252 {
            self.flag.read()
        }

        fn set_flag(ref self: ContractState, new_flag: felt252) {
            self.access_control.assert_only_role(DEFAULT_ADMIN_ROLE);
            let previous_flag = self.flag.read();
            self.flag.write(new_flag);
            self.emit(FlagSet { previous_flag, new_flag });
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(MINTER_ROLE);
            self.pausable.assert_not_paused();
            assert(!self.is_frozen(to), Errors::ADDRESS_FROZEN);
            self.erc20._mint(to, amount);
        }

        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(BURNER_ROLE);
            self.pausable.assert_not_paused();
            self._check_active_balance(from, amount);
            self.erc20._burn(from, amount);
        }

        fn freeze_address(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            self.frozen_addresses.write(account, true);
            self.emit(AddressFrozen { account });
        }

        fn unfreeze_address(ref self: ContractState, account: ContractAddress) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            self.frozen_addresses.write(account, false);
            self.emit(AddressUnfrozen { account });
        }

        fn is_frozen(self: @ContractState, account: ContractAddress) -> bool {
            self.frozen_addresses.read(account)
        }

        fn freeze_tokens(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            let current_frozen = self.frozen_tokens.read(account);
            self.frozen_tokens.write(account, current_frozen + amount);
            self.emit(TokensFrozen { account, amount });
        }

        fn unfreeze_tokens(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.access_control.assert_only_role(ENFORCER_ROLE);
            let current_frozen = self.frozen_tokens.read(account);
            assert(current_frozen >= amount, 'CMTAT: insufficient frozen tokens');
            self.frozen_tokens.write(account, current_frozen - amount);
            self.emit(TokensUnfrozen { account, amount });
        }

        fn get_frozen_tokens(self: @ContractState, account: ContractAddress) -> u256 {
            self.frozen_tokens.read(account)
        }

        fn active_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let total_balance = self.erc20.balance_of(account);
            let frozen_amount = self.frozen_tokens.read(account);
            if total_balance >= frozen_amount {
                total_balance - frozen_amount
            } else {
                0
            }
        }

        fn detect_transfer_restriction(
            self: @ContractState, 
            from: ContractAddress, 
            to: ContractAddress, 
            amount: u256
        ) -> u8 {
            // Basic ERC-1404 implementation
            if self.is_frozen(from) {
                return 2; // Sender frozen
            }
            if self.is_frozen(to) {
                return 3; // Recipient frozen
            }
            if self.active_balance_of(from) < amount {
                return 1; // Insufficient active balance
            }
            0 // No restriction
        }

        fn message_for_transfer_restriction(self: @ContractState, restriction_code: u8) -> felt252 {
            if restriction_code == 0 {
                'No restriction'
            } else if restriction_code == 1 {
                'Insufficient active balance'
            } else if restriction_code == 2 {
                'Sender frozen'
            } else if restriction_code == 3 {
                'Recipient frozen'
            } else {
                'Unknown restriction'
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _check_active_balance(self: @ContractState, account: ContractAddress, amount: u256) {
            let active_balance = self.active_balance_of(account);
            assert(active_balance >= amount, Errors::INSUFFICIENT_ACTIVE_BALANCE);
        }

        fn _before_update(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            self.pausable.assert_not_paused();
            
            // Skip checks for minting (from == 0) and burning (to == 0)
            if from.is_non_zero() {
                assert(!self.is_frozen(from), Errors::ADDRESS_FROZEN);
                self._check_active_balance(from, amount);
            }
            
            if to.is_non_zero() {
                assert(!self.is_frozen(to), Errors::ADDRESS_FROZEN);
            }
        }
    }

    // Implement the hook for transfer validation
    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let mut contract_state = ERC20Component::HasComponent::get_contract_mut(ref self);
            contract_state._before_update(from, to, amount);
        }

        fn after_update(
            ref self: ComponentState<ContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            // No post-transfer logic needed
        }
    }
}

#[starknet::interface]
trait ICMTAT<TContractState> {
    // Metadata
    fn terms(self: @TContractState) -> felt252;
    fn set_terms(ref self: TContractState, new_terms: felt252);
    fn flag(self: @TContractState) -> felt252;
    fn set_flag(ref self: TContractState, new_flag: felt252);
    
    // Minting and burning
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256);
    
    // Enforcement
    fn freeze_address(ref self: TContractState, account: ContractAddress);
    fn unfreeze_address(ref self: TContractState, account: ContractAddress);
    fn is_frozen(self: @TContractState, account: ContractAddress) -> bool;
    fn freeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn unfreeze_tokens(ref self: TContractState, account: ContractAddress, amount: u256);
    fn get_frozen_tokens(self: @TContractState, account: ContractAddress) -> u256;
    fn active_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    
    // ERC-1404 compliance
    fn detect_transfer_restriction(
        self: @TContractState, 
        from: ContractAddress, 
        to: ContractAddress, 
        amount: u256
    ) -> u8;
    fn message_for_transfer_restriction(self: @TContractState, restriction_code: u8) -> felt252;
}