// SPDX-License-Identifier: MPL-2.0
// Allowlist CMTAT Token Implementation

#[starknet::contract]
pub mod AllowlistCMTAT {
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::icmtat::{ICMTAT, ICMTATExtended, TokenType};
    use crate::modules::access_control::{AccessControlComponent, AccessControlImpl, Roles};
    use crate::modules::pause::{PauseComponent, PauseImpl};
    use crate::modules::enforcement::{EnforcementComponent, EnforcementImpl};
    use crate::modules::erc20_base::{ERC20BaseComponent, ERC20BaseImpl};
    use crate::modules::erc20_mint::{ERC20MintComponent, ERC20MintImpl};
    use crate::modules::erc20_burn::{ERC20BurnComponent, ERC20BurnImpl};
    use crate::modules::validation::{ValidationComponent, ValidationImpl};

    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: PauseComponent, storage: pause, event: PauseEvent);
    component!(path: EnforcementComponent, storage: enforcement, event: EnforcementEvent);
    component!(path: ERC20BaseComponent, storage: erc20_base, event: ERC20BaseEvent);
    component!(path: ERC20MintComponent, storage: erc20_mint, event: ERC20MintEvent);
    component!(path: ERC20BurnComponent, storage: erc20_burn, event: ERC20BurnEvent);
    component!(path: ValidationComponent, storage: validation, event: ValidationEvent);

    #[abi(embed_v0)]
    impl AccessControlPublic = AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausePublic = PauseImpl<ContractState>;
    #[abi(embed_v0)]
    impl EnforcementPublic = EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20BasePublic = ERC20BaseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MintPublic = ERC20MintImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20BurnPublic = ERC20BurnImpl<ContractState>;
    #[abi(embed_v0)]
    impl ValidationPublic = ValidationImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        pause: PauseComponent::Storage,
        #[substorage(v0)]
        enforcement: EnforcementComponent::Storage,
        #[substorage(v0)]
        erc20_base: ERC20BaseComponent::Storage,
        #[substorage(v0)]
        erc20_mint: ERC20MintComponent::Storage,
        #[substorage(v0)]
        erc20_burn: ERC20BurnComponent::Storage,
        #[substorage(v0)]
        validation: ValidationComponent::Storage,
        // Token metadata
        name: felt252,
        symbol: felt252,
        decimals: u8,
        token_type: TokenType,
        terms: felt252,
        flag: felt252,
        // Allowlist-specific storage
        allowlist: LegacyMap<ContractAddress, bool>,
        allowlist_count: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        PauseEvent: PauseComponent::Event,
        #[flat]
        EnforcementEvent: EnforcementComponent::Event,
        #[flat]
        ERC20BaseEvent: ERC20BaseComponent::Event,
        #[flat]
        ERC20MintEvent: ERC20MintComponent::Event,
        #[flat]
        ERC20BurnEvent: ERC20BurnComponent::Event,
        #[flat]
        ValidationEvent: ValidationComponent::Event,
        TermsSet: TermsSet,
        FlagSet: FlagSet,
        AddressAllowlisted: AddressAllowlisted,
        AddressRemovedFromAllowlist: AddressRemovedFromAllowlist,
        BatchAllowlistUpdate: BatchAllowlistUpdate,
    }

    #[derive(Drop, starknet::Event)]
    struct TermsSet {
        #[key]
        pub previous_terms: felt252,
        #[key]
        pub new_terms: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct FlagSet {
        #[key]
        pub previous_flag: felt252,
        #[key]
        pub new_flag: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressAllowlisted {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub allowed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct AddressRemovedFromAllowlist {
        #[key]
        pub account: ContractAddress,
        #[key]
        pub removed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BatchAllowlistUpdate {
        pub count: u256,
        #[key]
        pub updated_by: ContractAddress,
    }

    pub mod Errors {
        pub const ZERO_ADDRESS_ADMIN: felt252 = 'AllowlistCMTAT: zero admin';
        pub const NOT_ALLOWLISTED: felt252 = 'AllowlistCMTAT: not allowlisted';
        pub const ARRAYS_LENGTH_MISMATCH: felt252 = 'AllowlistCMTAT: length mismatch';
        pub const ZERO_ADDRESS: felt252 = 'AllowlistCMTAT: zero address';
    }

    // Custom role for allowlist management
    const ALLOWLIST_MANAGER: felt252 = 'ALLOWLIST_MANAGER';

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        terms: felt252,
        flag: felt252
    ) {
        assert(admin.is_non_zero(), Errors::ZERO_ADDRESS_ADMIN);

        // Initialize components
        self.access_control.initializer(admin);
        self.pause.initializer();
        self.enforcement.initializer();
        self.erc20_base.initializer(name, symbol, decimals);
        self.erc20_mint.initializer();
        self.erc20_burn.initializer();
        self.validation.initializer();

        // Set token metadata
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.token_type.write(TokenType::Allowlist);
        self.terms.write(terms);
        self.flag.write(flag);

        // Initialize allowlist
        self.allowlist_count.write(0);

        // Grant allowlist manager role to admin
        self.access_control.grant_role(ALLOWLIST_MANAGER, admin);
    }

    #[abi(embed_v0)]
    impl CMTATImpl of ICMTAT<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.erc20_base.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20_base.balance_of(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.erc20_base.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            // Check allowlist before transfer
            let from = get_caller_address();
            self._require_allowlisted(from);
            self._require_allowlisted(to);
            
            self.erc20_base.transfer(to, amount)
        }

        fn transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
            // Check allowlist before transfer
            self._require_allowlisted(from);
            self._require_allowlisted(to);
            
            self.erc20_base.transfer_from(from, to, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20_base.approve(spender, amount)
        }

        fn detect_transfer_restriction(
            self: @ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> u8 {
            // Check allowlist restrictions first
            if !self.is_allowlisted(from) {
                return 8; // SENDER_INVALID
            }
            if !self.is_allowlisted(to) {
                return 7; // RECIPIENT_INVALID
            }
            
            let (_, restriction_code) = self.validation.validate_transfer(from, to, amount);
            restriction_code
        }

        fn message_for_transfer_restriction(self: @ContractState, restriction_code: u8) -> felt252 {
            self.validation.get_restriction_message(restriction_code)
        }

        fn token_type(self: @ContractState) -> TokenType {
            self.token_type.read()
        }

        fn terms(self: @ContractState) -> felt252 {
            self.terms.read()
        }

        fn flag(self: @ContractState) -> felt252 {
            self.flag.read()
        }
    }

    #[abi(embed_v0)]
    impl CMTATExtendedImpl of ICMTATExtended<ContractState> {
        fn set_terms(ref self: ContractState, new_terms: felt252) {
            self.access_control.only_admin();
            let previous_terms = self.terms.read();
            self.terms.write(new_terms);
            self.emit(TermsSet { previous_terms, new_terms });
        }

        fn set_flag(ref self: ContractState, new_flag: felt252) {
            self.access_control.only_admin();
            let previous_flag = self.flag.read();
            self.flag.write(new_flag);
            self.emit(FlagSet { previous_flag, new_flag });
        }

        fn forced_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
            self.erc20_base.forced_transfer(from, to, amount)
        }

        fn batch_transfer(
            ref self: ContractState,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
            // Check all recipients are allowlisted
            let mut i = 0;
            loop {
                if i >= recipients.len() {
                    break;
                }
                self._require_allowlisted(*recipients.at(i));
                i += 1;
            };
            
            self.erc20_base.batch_transfer(recipients, amounts)
        }

        fn batch_transfer_from(
            ref self: ContractState,
            senders: Array<ContractAddress>,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
            // Check all senders and recipients are allowlisted
            let mut i = 0;
            loop {
                if i >= senders.len() {
                    break;
                }
                self._require_allowlisted(*senders.at(i));
                self._require_allowlisted(*recipients.at(i));
                i += 1;
            };
            
            self.erc20_base.batch_transfer_from(senders, recipients, amounts)
        }

        fn information(self: @ContractState) -> (felt252, felt252, u8, TokenType, felt252, felt252) {
            (
                self.name(),
                self.symbol(),
                self.decimals(),
                self.token_type(),
                self.terms(),
                self.flag()
            )
        }
    }

    // Allowlist-specific functions
    #[abi(embed_v0)]
    impl AllowlistFunctionsImpl of IAllowlistFunctions<ContractState> {
        fn is_allowlisted(self: @ContractState, account: ContractAddress) -> bool {
            self.allowlist.read(account)
        }

        fn add_to_allowlist(ref self: ContractState, account: ContractAddress) {
            self._only_allowlist_manager();
            assert(account.is_non_zero(), Errors::ZERO_ADDRESS);
            
            if !self.allowlist.read(account) {
                self.allowlist.write(account, true);
                self.allowlist_count.write(self.allowlist_count.read() + 1);
                
                let caller = get_caller_address();
                self.emit(AddressAllowlisted { account, allowed_by: caller });
            }
        }

        fn remove_from_allowlist(ref self: ContractState, account: ContractAddress) {
            self._only_allowlist_manager();
            
            if self.allowlist.read(account) {
                self.allowlist.write(account, false);
                self.allowlist_count.write(self.allowlist_count.read() - 1);
                
                let caller = get_caller_address();
                self.emit(AddressRemovedFromAllowlist { account, removed_by: caller });
            }
        }

        fn batch_allowlist_update(
            ref self: ContractState,
            accounts: Array<ContractAddress>,
            statuses: Array<bool>
        ) {
            self._only_allowlist_manager();
            assert(accounts.len() == statuses.len(), Errors::ARRAYS_LENGTH_MISMATCH);
            
            let mut i = 0;
            let mut changes = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                
                let account = *accounts.at(i);
                let status = *statuses.at(i);
                assert(account.is_non_zero(), Errors::ZERO_ADDRESS);
                
                let current_status = self.allowlist.read(account);
                if current_status != status {
                    self.allowlist.write(account, status);
                    if status {
                        self.allowlist_count.write(self.allowlist_count.read() + 1);
                    } else {
                        self.allowlist_count.write(self.allowlist_count.read() - 1);
                    }
                    changes += 1;
                }
                
                i += 1;
            };
            
            let caller = get_caller_address();
            self.emit(BatchAllowlistUpdate { count: changes, updated_by: caller });
        }

        fn get_allowlist_count(self: @ContractState) -> u256 {
            self.allowlist_count.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _require_allowlisted(self: @ContractState, account: ContractAddress) {
            assert(self.is_allowlisted(account), Errors::NOT_ALLOWLISTED);
        }

        fn _only_allowlist_manager(self: @ContractState) {
            let caller = get_caller_address();
            assert(
                self.access_control.has_role(ALLOWLIST_MANAGER, caller) ||
                self.access_control.has_role(Roles::DEFAULT_ADMIN, caller),
                'AllowlistCMTAT: not manager'
            );
        }
    }

    #[starknet::interface]
    trait IAllowlistFunctions<TContractState> {
        fn is_allowlisted(self: @TContractState, account: ContractAddress) -> bool;
        fn add_to_allowlist(ref self: TContractState, account: ContractAddress);
        fn remove_from_allowlist(ref self: TContractState, account: ContractAddress);
        fn batch_allowlist_update(
            ref self: TContractState,
            accounts: Array<ContractAddress>,
            statuses: Array<bool>
        );
        fn get_allowlist_count(self: @TContractState) -> u256;
    }
}