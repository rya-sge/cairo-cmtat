// SPDX-License-Identifier: MPL-2.0
// Light CMTAT Token Implementation (Minimal Features)

#[starknet::contract]
pub mod LightCMTAT {
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::icmtat::{ICMTAT, ICMTATExtended, TokenType};
    use crate::modules::access_control::{AccessControlComponent, AccessControlImpl};
    use crate::modules::erc20_base::{ERC20BaseComponent, ERC20BaseImpl};
    use crate::modules::erc20_mint::{ERC20MintComponent, ERC20MintImpl};

    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: ERC20BaseComponent, storage: erc20_base, event: ERC20BaseEvent);
    component!(path: ERC20MintComponent, storage: erc20_mint, event: ERC20MintEvent);

    #[abi(embed_v0)]
    impl AccessControlPublic = AccessControlImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20BasePublic = ERC20BaseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MintPublic = ERC20MintImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        erc20_base: ERC20BaseComponent::Storage,
        #[substorage(v0)]
        erc20_mint: ERC20MintComponent::Storage,
        // Token metadata
        name: felt252,
        symbol: felt252,
        decimals: u8,
        token_type: TokenType,
        terms: felt252,
        flag: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        ERC20BaseEvent: ERC20BaseComponent::Event,
        #[flat]
        ERC20MintEvent: ERC20MintComponent::Event,
        TermsSet: TermsSet,
        FlagSet: FlagSet,
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

    pub mod Errors {
        pub const ZERO_ADDRESS_ADMIN: felt252 = 'LightCMTAT: zero admin';
    }

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

        // Initialize components (minimal set)
        self.access_control.initializer(admin);
        self.erc20_base.initializer(name, symbol, decimals);
        self.erc20_mint.initializer();

        // Set token metadata
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.token_type.write(TokenType::Light);
        self.terms.write(terms);
        self.flag.write(flag);
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
            // Light version - minimal validation
            self.erc20_base._transfer(get_caller_address(), to, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> bool {
            // Light version - minimal validation
            self.erc20_base._spend_allowance(from, get_caller_address(), amount);
            self.erc20_base._transfer(from, to, amount);
            true
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
            // Light version - no restrictions
            0 // NO_RESTRICTION
        }

        fn message_for_transfer_restriction(self: @ContractState, restriction_code: u8) -> felt252 {
            if restriction_code == 0 {
                'No restriction'
            } else {
                'Unknown restriction'
            }
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
            // Light version - only admin can force transfer
            self.access_control.only_admin();
            self.erc20_base._transfer(from, to, amount);
            true
        }

        fn batch_transfer(
            ref self: ContractState,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
            // Light version - simplified batch transfer
            assert(recipients.len() == amounts.len(), 'LightCMTAT: length mismatch');
            
            let sender = get_caller_address();
            let mut i = 0;
            loop {
                if i >= recipients.len() {
                    break;
                }
                
                let to = *recipients.at(i);
                let amount = *amounts.at(i);
                self.erc20_base._transfer(sender, to, amount);
                
                i += 1;
            };
            true
        }

        fn batch_transfer_from(
            ref self: ContractState,
            senders: Array<ContractAddress>,
            recipients: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
            // Light version - simplified batch transfer from
            assert(senders.len() == recipients.len(), 'LightCMTAT: length mismatch');
            assert(recipients.len() == amounts.len(), 'LightCMTAT: length mismatch');
            
            let spender = get_caller_address();
            let mut i = 0;
            loop {
                if i >= senders.len() {
                    break;
                }
                
                let from = *senders.at(i);
                let to = *recipients.at(i);
                let amount = *amounts.at(i);
                
                self.erc20_base._spend_allowance(from, spender, amount);
                self.erc20_base._transfer(from, to, amount);
                
                i += 1;
            };
            true
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
}