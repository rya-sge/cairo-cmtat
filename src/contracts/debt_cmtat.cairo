// SPDX-License-Identifier: MPL-2.0
// Debt CMTAT Token Implementation

#[starknet::contract]
pub mod DebtCMTAT {
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::icmtat::{ICMTAT, ICMTATExtended, TokenType};
    use crate::modules::access_control::{AccessControlComponent, AccessControlImpl};
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
        // Debt-specific fields
        interest_rate: u256,
        maturity_date: u64,
        credit_events: felt252,
        bondholders_reserve: ContractAddress,
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
        InterestRateSet: InterestRateSet,
        MaturityDateSet: MaturityDateSet,
        CreditEventOccurred: CreditEventOccurred,
        BondholdersReserveSet: BondholdersReserveSet,
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
    struct InterestRateSet {
        #[key]
        pub previous_rate: u256,
        #[key]
        pub new_rate: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct MaturityDateSet {
        #[key]
        pub previous_date: u64,
        #[key]
        pub new_date: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CreditEventOccurred {
        #[key]
        pub event_type: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct BondholdersReserveSet {
        #[key]
        pub previous_reserve: ContractAddress,
        #[key]
        pub new_reserve: ContractAddress,
    }

    pub mod Errors {
        pub const ZERO_ADDRESS_ADMIN: felt252 = 'DebtCMTAT: zero admin';
        pub const INVALID_INTEREST_RATE: felt252 = 'DebtCMTAT: invalid rate';
        pub const INVALID_MATURITY_DATE: felt252 = 'DebtCMTAT: invalid maturity';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        terms: felt252,
        flag: felt252,
        interest_rate: u256,
        maturity_date: u64,
        bondholders_reserve: ContractAddress
    ) {
        assert(admin.is_non_zero(), Errors::ZERO_ADDRESS_ADMIN);
        assert(interest_rate <= 10000, Errors::INVALID_INTEREST_RATE); // Max 100% in basis points
        assert(maturity_date > starknet::get_block_timestamp(), Errors::INVALID_MATURITY_DATE);

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
        self.token_type.write(TokenType::Debt);
        self.terms.write(terms);
        self.flag.write(flag);

        // Set debt-specific fields
        self.interest_rate.write(interest_rate);
        self.maturity_date.write(maturity_date);
        self.credit_events.write(0);
        self.bondholders_reserve.write(bondholders_reserve);
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
            self.erc20_base.transfer(to, amount)
        }

        fn transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
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
            self.erc20_base.batch_transfer(recipients, amounts)
        }

        fn batch_transfer_from(
            ref self: ContractState,
            senders: Array<ContractAddress>,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
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

    // Debt-specific functions
    #[abi(embed_v0)]
    impl DebtFunctionsImpl of IDebtFunctions<ContractState> {
        fn get_interest_rate(self: @ContractState) -> u256 {
            self.interest_rate.read()
        }

        fn set_interest_rate(ref self: ContractState, new_rate: u256) {
            self.access_control.only_admin();
            assert(new_rate <= 10000, Errors::INVALID_INTEREST_RATE);
            let previous_rate = self.interest_rate.read();
            self.interest_rate.write(new_rate);
            self.emit(InterestRateSet { previous_rate, new_rate });
        }

        fn get_maturity_date(self: @ContractState) -> u64 {
            self.maturity_date.read()
        }

        fn set_maturity_date(ref self: ContractState, new_date: u64) {
            self.access_control.only_admin();
            assert(new_date > starknet::get_block_timestamp(), Errors::INVALID_MATURITY_DATE);
            let previous_date = self.maturity_date.read();
            self.maturity_date.write(new_date);
            self.emit(MaturityDateSet { previous_date, new_date });
        }

        fn trigger_credit_event(ref self: ContractState, event_type: felt252) {
            self.access_control.only_admin();
            self.credit_events.write(event_type);
            self.emit(CreditEventOccurred { event_type, timestamp: starknet::get_block_timestamp() });
        }

        fn get_bondholders_reserve(self: @ContractState) -> ContractAddress {
            self.bondholders_reserve.read()
        }

        fn set_bondholders_reserve(ref self: ContractState, new_reserve: ContractAddress) {
            self.access_control.only_admin();
            let previous_reserve = self.bondholders_reserve.read();
            self.bondholders_reserve.write(new_reserve);
            self.emit(BondholdersReserveSet { previous_reserve, new_reserve });
        }
    }

    #[starknet::interface]
    trait IDebtFunctions<TContractState> {
        fn get_interest_rate(self: @TContractState) -> u256;
        fn set_interest_rate(ref self: TContractState, new_rate: u256);
        fn get_maturity_date(self: @TContractState) -> u64;
        fn set_maturity_date(ref self: TContractState, new_date: u64);
        fn trigger_credit_event(ref self: TContractState, event_type: felt252);
        fn get_bondholders_reserve(self: @TContractState) -> ContractAddress;
        fn set_bondholders_reserve(ref self: TContractState, new_reserve: ContractAddress);
    }
}