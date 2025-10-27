// SPDX-License-Identifier: MPL-2.0
// Validation Module for CMTAT Cairo Implementation

use starknet::ContractAddress;
use crate::interfaces::engines::{IRuleEngine, ISnapshotEngine, IDocumentEngine, IDebtEngine};

#[starknet::interface]
pub trait IValidation<TContractState> {
    fn validate_transfer(
        self: @TContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256
    ) -> (bool, u8);
    fn set_rule_engine(ref self: TContractState, rule_engine: ContractAddress);
    fn get_rule_engine(self: @TContractState) -> ContractAddress;
    fn set_snapshot_engine(ref self: TContractState, snapshot_engine: ContractAddress);
    fn get_snapshot_engine(self: @TContractState) -> ContractAddress;
    fn set_document_engine(ref self: TContractState, document_engine: ContractAddress);
    fn get_document_engine(self: @TContractState) -> ContractAddress;
    fn set_debt_engine(ref self: TContractState, debt_engine: ContractAddress);
    fn get_debt_engine(self: @TContractState) -> ContractAddress;
}

#[starknet::component]
pub mod ValidationComponent {
    use super::{IValidation, ContractAddress, IRuleEngine, ISnapshotEngine, IDocumentEngine, IDebtEngine};
    use starknet::{get_caller_address, contract_address_const, syscalls::call_contract_syscall};
    use crate::modules::access_control::{AccessControlComponent, only_admin};

    #[storage]
    struct Storage {
        rule_engine: ContractAddress,
        snapshot_engine: ContractAddress,
        document_engine: ContractAddress,
        debt_engine: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RuleEngineSet: RuleEngineSet,
        SnapshotEngineSet: SnapshotEngineSet,
        DocumentEngineSet: DocumentEngineSet,
        DebtEngineSet: DebtEngineSet,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RuleEngineSet {
        #[key]
        pub previous_engine: ContractAddress,
        #[key]
        pub new_engine: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SnapshotEngineSet {
        #[key]
        pub previous_engine: ContractAddress,
        #[key]
        pub new_engine: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DocumentEngineSet {
        #[key]
        pub previous_engine: ContractAddress,
        #[key]
        pub new_engine: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DebtEngineSet {
        #[key]
        pub previous_engine: ContractAddress,
        #[key]
        pub new_engine: ContractAddress,
    }

    pub mod Errors {
        pub const ZERO_ADDRESS: felt252 = 'Validation: zero address';
        pub const ENGINE_CALL_FAILED: felt252 = 'Validation: engine call failed';
    }

    // Transfer restriction codes (ERC-1404 compliant)
    pub mod RestrictionCodes {
        pub const NO_RESTRICTION: u8 = 0;
        pub const FROM_BALANCE_INSUFFICIENT: u8 = 1;
        pub const FROM_FROZEN: u8 = 2;
        pub const TO_FROZEN: u8 = 3;
        pub const RULE_ENGINE_RESTRICTION: u8 = 4;
        pub const GLOBAL_RESTRICTION: u8 = 5;
        pub const AMOUNT_TOO_HIGH: u8 = 6;
        pub const RECIPIENT_INVALID: u8 = 7;
        pub const SENDER_INVALID: u8 = 8;
        pub const DEBT_ENGINE_RESTRICTION: u8 = 9;
    }

    #[embeddable_as(ValidationImpl)]
    impl Validation<
        TContractState,
        +HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IValidation<ComponentState<TContractState>> {
        fn validate_transfer(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> (bool, u8) {
            // Basic validation - zero addresses
            if from.is_zero() {
                return (false, RestrictionCodes::SENDER_INVALID);
            }
            if to.is_zero() {
                return (false, RestrictionCodes::RECIPIENT_INVALID);
            }

            // Check rule engine if set
            let rule_engine = self.rule_engine.read();
            if rule_engine.is_non_zero() {
                let (is_valid, restriction_code) = self._call_rule_engine(rule_engine, from, to, amount);
                if !is_valid {
                    return (false, restriction_code);
                }
            }

            // Check debt engine if set
            let debt_engine = self.debt_engine.read();
            if debt_engine.is_non_zero() {
                let (is_valid, restriction_code) = self._call_debt_engine(debt_engine, from, to, amount);
                if !is_valid {
                    return (false, restriction_code);
                }
            }

            // All checks passed
            (true, RestrictionCodes::NO_RESTRICTION)
        }

        fn set_rule_engine(ref self: ComponentState<TContractState>, rule_engine: ContractAddress) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);

            let previous_engine = self.rule_engine.read();
            self.rule_engine.write(rule_engine);

            self.emit(RuleEngineSet { previous_engine, new_engine: rule_engine });
        }

        fn get_rule_engine(self: @ComponentState<TContractState>) -> ContractAddress {
            self.rule_engine.read()
        }

        fn set_snapshot_engine(ref self: ComponentState<TContractState>, snapshot_engine: ContractAddress) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);

            let previous_engine = self.snapshot_engine.read();
            self.snapshot_engine.write(snapshot_engine);

            self.emit(SnapshotEngineSet { previous_engine, new_engine: snapshot_engine });
        }

        fn get_snapshot_engine(self: @ComponentState<TContractState>) -> ContractAddress {
            self.snapshot_engine.read()
        }

        fn set_document_engine(ref self: ComponentState<TContractState>, document_engine: ContractAddress) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);

            let previous_engine = self.document_engine.read();
            self.document_engine.write(document_engine);

            self.emit(DocumentEngineSet { previous_engine, new_engine: document_engine });
        }

        fn get_document_engine(self: @ComponentState<TContractState>) -> ContractAddress {
            self.document_engine.read()
        }

        fn set_debt_engine(ref self: ComponentState<TContractState>, debt_engine: ContractAddress) {
            let mut access_control = get_dep_component_mut!(ref self, AccessControl);
            only_admin(@access_control);

            let previous_engine = self.debt_engine.read();
            self.debt_engine.write(debt_engine);

            self.emit(DebtEngineSet { previous_engine, new_engine: debt_engine });
        }

        fn get_debt_engine(self: @ComponentState<TContractState>) -> ContractAddress {
            self.debt_engine.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            self.rule_engine.write(contract_address_const::<0>());
            self.snapshot_engine.write(contract_address_const::<0>());
            self.document_engine.write(contract_address_const::<0>());
            self.debt_engine.write(contract_address_const::<0>());
        }

        fn _call_rule_engine(
            self: @ComponentState<TContractState>,
            rule_engine: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> (bool, u8) {
            // Create rule engine dispatcher
            let rule_engine_dispatcher = IRuleEngineDispatcher { contract_address: rule_engine };
            
            // Call validate_transfer on rule engine
            match rule_engine_dispatcher.validate_transfer(from, to, amount) {
                Result::Ok((is_valid, restriction_code)) => {
                    if is_valid {
                        (true, RestrictionCodes::NO_RESTRICTION)
                    } else {
                        (false, restriction_code)
                    }
                },
                Result::Err(_) => {
                    // If rule engine call fails, default to restriction
                    (false, RestrictionCodes::RULE_ENGINE_RESTRICTION)
                }
            }
        }

        fn _call_debt_engine(
            self: @ComponentState<TContractState>,
            debt_engine: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) -> (bool, u8) {
            // Create debt engine dispatcher
            let debt_engine_dispatcher = IDebtEngineDispatcher { contract_address: debt_engine };
            
            // Call validate_transfer on debt engine
            match debt_engine_dispatcher.validate_transfer(from, to, amount) {
                Result::Ok((is_valid, restriction_code)) => {
                    if is_valid {
                        (true, RestrictionCodes::NO_RESTRICTION)
                    } else {
                        (false, restriction_code)
                    }
                },
                Result::Err(_) => {
                    // If debt engine call fails, default to restriction
                    (false, RestrictionCodes::DEBT_ENGINE_RESTRICTION)
                }
            }
        }

        fn get_restriction_message(restriction_code: u8) -> felt252 {
            match restriction_code {
                0 => 'No restriction',
                1 => 'Insufficient balance',
                2 => 'Sender frozen',
                3 => 'Recipient frozen',
                4 => 'Rule engine restriction',
                5 => 'Global restriction',
                6 => 'Amount too high',
                7 => 'Invalid recipient',
                8 => 'Invalid sender',
                9 => 'Debt engine restriction',
                _ => 'Unknown restriction'
            }
        }
    }
}