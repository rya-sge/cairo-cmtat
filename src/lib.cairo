// SPDX-License-Identifier: MPL-2.0
// Cairo CMTAT Implementation Library

// Working CMTAT implementation (temporarily disabled for compilation)
// pub mod working_cmtat;

// Note: Advanced CMTAT modules temporarily disabled for compilation
// pub mod interfaces {
//     pub mod icmtat;
//     pub mod engines;
// }

// pub mod modules {
//     pub mod access_control;
//     pub mod pause;
//     pub mod enforcement;
//     pub mod erc20_base;
//     pub mod erc20_mint;
//     pub mod erc20_burn;
//     pub mod validation;
// }

// pub mod contracts {
//     pub mod standard_cmtat;
//     pub mod debt_cmtat;
//     pub mod allowlist_cmtat;
//     pub mod light_cmtat;
// }

// Legacy simple ERC20 implementation (working)
#[starknet::contract]
mod CMTAT_ERC20 {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // External
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    // Internal
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, recipient: ContractAddress) {
        let initial_supply: u256 = 1000000000000000000000000; // 1,000,000 tokens with 18 decimals
        self.erc20.initializer("CMTAT Token", "CMTAT");
        self.erc20._mint(recipient, initial_supply);
    }
}
