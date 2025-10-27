// SPDX-License-Identifier: MPL-2.0
// Test Suite for CMTAT Cairo Implementation

#[cfg(test)]
mod cmtat_tests {
    use super::super::contracts::{
        standard_cmtat::{StandardCMTAT, IStandardCMTATDispatcher, IStandardCMTATDispatcherTrait},
        debt_cmtat::{DebtCMTAT, IDebtCMTATDispatcher, IDebtCMTATDispatcherTrait},
        allowlist_cmtat::{AllowlistCMTAT, IAllowlistCMTATDispatcher, IAllowlistCMTATDispatcherTrait},
        light_cmtat::{LightCMTAT, ILightCMTATDispatcher, ILightCMTATDispatcherTrait},
    };
    use super::super::interfaces::icmtat::{ICMTAT, ICMTATExtended, TokenType};
    use starknet::{
        ContractAddress, contract_address_const, deploy_syscall, get_caller_address,
        testing::{set_caller_address, set_block_timestamp}
    };
    use snforge_std::{declare, ContractClassTrait, cheat_caller_address, CheatSpan};

    // Test constants
    const ADMIN: felt252 = 0x123;
    const USER1: felt252 = 0x456;
    const USER2: felt252 = 0x789;
    const MINTER: felt252 = 0xabc;
    const BURNER: felt252 = 0xdef;

    fn admin() -> ContractAddress { contract_address_const::<ADMIN>() }
    fn user1() -> ContractAddress { contract_address_const::<USER1>() }
    fn user2() -> ContractAddress { contract_address_const::<USER2>() }
    fn minter() -> ContractAddress { contract_address_const::<MINTER>() }
    fn burner() -> ContractAddress { contract_address_const::<BURNER>() }

    #[test]
    fn test_standard_cmtat_deployment() {
        let contract = declare("StandardCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Standard',
            'CMTAT-STD',
            18,
            'Terms and Conditions',
            'FLAG001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = ICMTATDispatcher { contract_address };

        // Test basic functionality
        assert(dispatcher.name() == 'CMTAT Standard', 'Wrong name');
        assert(dispatcher.symbol() == 'CMTAT-STD', 'Wrong symbol');
        assert(dispatcher.decimals() == 18, 'Wrong decimals');
        assert(dispatcher.token_type() == TokenType::Standard, 'Wrong token type');
        assert(dispatcher.terms() == 'Terms and Conditions', 'Wrong terms');
        assert(dispatcher.flag() == 'FLAG001', 'Wrong flag');
        assert(dispatcher.total_supply() == 0, 'Wrong initial supply');
    }

    #[test]
    fn test_debt_cmtat_deployment() {
        let contract = declare("DebtCMTAT").unwrap();
        
        let interest_rate = 500; // 5% in basis points
        let maturity_date = 1735689600; // Future timestamp
        let bondholders_reserve = user1();

        let constructor_calldata = array![
            admin().into(),
            'CMTAT Debt Token',
            'CMTAT-DEBT',
            18,
            'Debt Terms',
            'DEBT001',
            interest_rate.into(),
            maturity_date.into(),
            bondholders_reserve.into()
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = ICMTATDispatcher { contract_address };

        // Test basic functionality
        assert(dispatcher.name() == 'CMTAT Debt Token', 'Wrong name');
        assert(dispatcher.token_type() == TokenType::Debt, 'Wrong token type');
        
        // Test debt-specific functionality
        let debt_dispatcher = IDebtFunctionsDispatcher { contract_address };
        assert(debt_dispatcher.get_interest_rate() == 500, 'Wrong interest rate');
        assert(debt_dispatcher.get_maturity_date() == maturity_date, 'Wrong maturity date');
        assert(debt_dispatcher.get_bondholders_reserve() == bondholders_reserve, 'Wrong reserve');
    }

    #[test]
    fn test_allowlist_cmtat_functionality() {
        let contract = declare("AllowlistCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Allowlist',
            'CMTAT-AL',
            18,
            'Allowlist Terms',
            'AL001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = ICMTATDispatcher { contract_address };
        let allowlist_dispatcher = IAllowlistFunctionsDispatcher { contract_address };

        // Test allowlist functionality
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        allowlist_dispatcher.add_to_allowlist(user1());
        
        assert(allowlist_dispatcher.is_allowlisted(user1()), 'User1 not allowlisted');
        assert(!allowlist_dispatcher.is_allowlisted(user2()), 'User2 should not be allowlisted');
        assert(allowlist_dispatcher.get_allowlist_count() == 1, 'Wrong allowlist count');

        // Test batch allowlist update
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        allowlist_dispatcher.batch_allowlist_update(
            array![user2(), user1()],
            array![true, false]
        );
        
        assert(allowlist_dispatcher.is_allowlisted(user2()), 'User2 not allowlisted');
        assert(!allowlist_dispatcher.is_allowlisted(user1()), 'User1 should not be allowlisted');
        assert(allowlist_dispatcher.get_allowlist_count() == 1, 'Wrong allowlist count after batch');
    }

    #[test]
    fn test_light_cmtat_minimal_features() {
        let contract = declare("LightCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Light',
            'CMTAT-LIGHT',
            18,
            'Light Terms',
            'LIGHT001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = ICMTATDispatcher { contract_address };

        // Test basic functionality
        assert(dispatcher.name() == 'CMTAT Light', 'Wrong name');
        assert(dispatcher.token_type() == TokenType::Light, 'Wrong token type');
        
        // Test no restrictions in light version
        let restriction = dispatcher.detect_transfer_restriction(user1(), user2(), 1000);
        assert(restriction == 0, 'Should have no restrictions');
        
        let message = dispatcher.message_for_transfer_restriction(0);
        assert(message == 'No restriction', 'Wrong restriction message');
    }

    #[test]
    fn test_minting_and_burning() {
        let contract = declare("StandardCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Test',
            'CMTAT-TST',
            18,
            'Test Terms',
            'TEST001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = ICMTATDispatcher { contract_address };
        let mint_dispatcher = IERC20MintDispatcher { contract_address };
        let burn_dispatcher = IERC20BurnDispatcher { contract_address };

        // Grant minter and burner roles
        let access_dispatcher = IAccessControlDispatcher { contract_address };
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(2));
        access_dispatcher.grant_role('MINTER', minter());
        access_dispatcher.grant_role('BURNER', burner());

        // Test minting
        cheat_caller_address(contract_address, minter(), CheatSpan::TargetCalls(1));
        mint_dispatcher.mint(user1(), 1000);
        
        assert(dispatcher.balance_of(user1()) == 1000, 'Wrong balance after mint');
        assert(dispatcher.total_supply() == 1000, 'Wrong total supply after mint');

        // Test burning
        cheat_caller_address(contract_address, burner(), CheatSpan::TargetCalls(1));
        burn_dispatcher.burn(user1(), 500);
        
        assert(dispatcher.balance_of(user1()) == 500, 'Wrong balance after burn');
        assert(dispatcher.total_supply() == 500, 'Wrong total supply after burn');
    }

    #[test]
    fn test_pause_functionality() {
        let contract = declare("StandardCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Test',
            'CMTAT-TST',
            18,
            'Test Terms',
            'TEST001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let pause_dispatcher = IPauseDispatcher { contract_address };

        // Test initial state
        assert(!pause_dispatcher.is_paused(), 'Should not be paused initially');
        assert(!pause_dispatcher.is_deactivated(), 'Should not be deactivated initially');

        // Test pause
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        pause_dispatcher.pause();
        assert(pause_dispatcher.is_paused(), 'Should be paused');

        // Test unpause
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        pause_dispatcher.unpause();
        assert(!pause_dispatcher.is_paused(), 'Should not be paused');

        // Test deactivate
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        pause_dispatcher.deactivate('Test deactivation');
        assert(pause_dispatcher.is_deactivated(), 'Should be deactivated');
    }

    #[test]
    fn test_enforcement_functionality() {
        let contract = declare("StandardCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Test',
            'CMTAT-TST',
            18,
            'Test Terms',
            'TEST001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let enforcement_dispatcher = IEnforcementDispatcher { contract_address };

        // Grant enforcer role
        let access_dispatcher = IAccessControlDispatcher { contract_address };
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        access_dispatcher.grant_role('ENFORCER', admin());

        // Test address freezing
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        enforcement_dispatcher.freeze_address(user1());
        assert(enforcement_dispatcher.is_frozen(user1()), 'User1 should be frozen');

        // Test address unfreezing
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        enforcement_dispatcher.unfreeze_address(user1());
        assert(!enforcement_dispatcher.is_frozen(user1()), 'User1 should not be frozen');

        // Test partial freezing
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        enforcement_dispatcher.freeze_partial_tokens(user1(), 500);
        assert(enforcement_dispatcher.get_frozen_tokens(user1()) == 500, 'Wrong frozen amount');
    }

    #[test]
    fn test_access_control() {
        let contract = declare("StandardCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Test',
            'CMTAT-TST',
            18,
            'Test Terms',
            'TEST001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let access_dispatcher = IAccessControlDispatcher { contract_address };

        // Test admin role
        assert(access_dispatcher.has_role('DEFAULT_ADMIN', admin()), 'Admin should have DEFAULT_ADMIN role');
        assert(!access_dispatcher.has_role('MINTER', user1()), 'User1 should not have MINTER role');

        // Test role granting
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        access_dispatcher.grant_role('MINTER', user1());
        assert(access_dispatcher.has_role('MINTER', user1()), 'User1 should have MINTER role');

        // Test role revoking
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(1));
        access_dispatcher.revoke_role('MINTER', user1());
        assert(!access_dispatcher.has_role('MINTER', user1()), 'User1 should not have MINTER role');
    }

    #[test]
    #[should_panic(expected: ('CMTAT: transfer restricted',))]
    fn test_transfer_restrictions() {
        let contract = declare("AllowlistCMTAT").unwrap();
        
        let constructor_calldata = array![
            admin().into(),
            'CMTAT Allowlist',
            'CMTAT-AL',
            18,
            'Allowlist Terms',
            'AL001'
        ];

        let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
        let dispatcher = ICMTATDispatcher { contract_address };

        // Mint tokens to user1 (not allowlisted)
        let mint_dispatcher = IERC20MintDispatcher { contract_address };
        cheat_caller_address(contract_address, admin(), CheatSpan::TargetCalls(2));
        access_dispatcher.grant_role('MINTER', admin());
        mint_dispatcher.mint(user1(), 1000);

        // Try to transfer without being allowlisted (should fail)
        cheat_caller_address(contract_address, user1(), CheatSpan::TargetCalls(1));
        dispatcher.transfer(user2(), 100);
    }
}