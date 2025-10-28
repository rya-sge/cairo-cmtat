// SPDX-License-Identifier: MPL-2.0
// Cairo CMTAT Implementation Library

// Working CMTAT implementation
pub mod working_cmtat;

// CMTAT interfaces
pub mod interfaces {
    pub mod icmtat;
    // pub mod engines; // Temporarily disabled for compilation
}

// CMTAT contract implementations - All working and deployable
pub mod contracts {
    pub mod simple_standard_cmtat;
    pub mod simple_light_cmtat;
    pub mod simple_debt_cmtat;
}

// CMTAT modules (for future modular implementation)
// pub mod modules {
//     pub mod access_control;
//     pub mod pause;
//     pub mod enforcement;
//     pub mod erc20_base;
//     pub mod erc20_mint;
//     pub mod erc20_burn;
//     pub mod validation;
// }
