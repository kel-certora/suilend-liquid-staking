#[test_only]
module liquid_staking::weight_tests {
    use liquid_staking::{
        fees,
        liquid_staking::create_lst,
        test_utils::setup_runner,
        weight::{Self, WeightHook}
    };
    use sui::{coin, test_scenario, vec_map};
    use sui_system::sui_system::SuiSystemState;

    const MIST_PER_SUI: u64 = 1_000_000_000;

    public struct TEST has drop {}

    #[test]
    fun test_rebalance() {
        let mut runner = setup_runner(vector[100, 100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        runner.scenario_mut().next_tx(@0x0);

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx()).to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let sui = coin::mint_for_testing(100 * MIST_PER_SUI, runner.ctx());
        let lst = lst_info.mint(&mut system_state, sui, runner.ctx());

        assert!(lst_info.total_lst_supply() == 100 * MIST_PER_SUI);
        assert!(lst_info.storage().total_sui_supply() == 100 * MIST_PER_SUI);

        let (mut weight_hook, weight_hook_admin_cap) = weight::new(admin_cap, runner.ctx());

        weight_hook.set_validator_addresses_and_weights(
            &weight_hook_admin_cap,
            {
                let mut map = vec_map::empty();
                map.insert(validator_addresses[0], 100);
                map.insert(validator_addresses[1], 300);

                map
            },
        );

        weight_hook.rebalance(&mut system_state, &mut lst_info, runner.ctx());

        assert!(lst_info.storage().validators().borrow(0).total_sui_amount() == 25 * MIST_PER_SUI);
        assert!(lst_info.storage().validators().borrow(1).total_sui_amount() == 75 * MIST_PER_SUI);

        weight_hook.set_validator_addresses_and_weights(
            &weight_hook_admin_cap,
            {
                let mut map = vec_map::empty();
                map.insert(validator_addresses[2], 100);

                map
            },
        );
        weight_hook.rebalance(&mut system_state, &mut lst_info, runner.ctx());

        assert!(lst_info.storage().validators().borrow(0).total_sui_amount() == 0);
        assert!(lst_info.storage().validators().borrow(1).total_sui_amount() == 0);
        assert!(lst_info.storage().validators().borrow(2).total_sui_amount() == 100 * MIST_PER_SUI);

        // test update fees
        let new_fees = fees::new_builder(runner.ctx()).set_sui_mint_fee_bps(100).to_fee_config();
        weight_hook.update_fees(&weight_hook_admin_cap, &mut lst_info, new_fees);

        assert!(lst_info.fee_config().sui_mint_fee_bps() == 100);

        // mint some lst
        let sui = coin::mint_for_testing(100 * MIST_PER_SUI, runner.ctx());
        let lst2 = lst_info.mint(&mut system_state, sui, runner.ctx());

        // test collect fees
        let collected_fees = weight_hook.collect_fees(
            &weight_hook_admin_cap,
            &mut lst_info,
            &mut system_state,
            runner.ctx(),
        );
        assert!(collected_fees.value() == MIST_PER_SUI);

        // sharing to make sure shared object deletion actually works lol
        transfer::public_share_object(weight_hook);
        runner.scenario_mut().next_tx(@0x0);

        let weight_hook = runner.scenario_mut().take_shared<WeightHook<TEST>>();
        let admin_cap = weight_hook.eject(weight_hook_admin_cap);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);
        std::unit_test::destroy(lst);
        std::unit_test::destroy(lst2);
        std::unit_test::destroy(collected_fees);

        runner.finish();
    }

    #[test]
    fun test_custom_redeem_request() {
        let mut runner = setup_runner(vector[100, 100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        runner.scenario_mut().next_tx(@0x0);

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx()).set_custom_redeem_fee_bps(100).to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let sui = coin::mint_for_testing(100 * MIST_PER_SUI, runner.ctx());
        let mut lst = lst_info.mint(&mut system_state, sui, runner.ctx());

        assert!(lst_info.total_lst_supply() == 100 * MIST_PER_SUI);
        assert!(lst_info.storage().total_sui_supply() == 100 * MIST_PER_SUI);

        let (mut weight_hook, weight_hook_admin_cap) = weight::new(admin_cap, runner.ctx());

        weight_hook.set_validator_addresses_and_weights(
            &weight_hook_admin_cap,
            {
                let mut map = vec_map::empty();
                map.insert(validator_addresses[0], 100);
                map.insert(validator_addresses[1], 300);

                map
            },
        );

        weight_hook.rebalance(&mut system_state, &mut lst_info, runner.ctx());

        assert!(lst_info.storage().validators().borrow(0).total_sui_amount() == 25 * MIST_PER_SUI);
        assert!(lst_info.storage().validators().borrow(1).total_sui_amount() == 75 * MIST_PER_SUI);

        let lst_to_unstake = lst.split(10 * MIST_PER_SUI, runner.ctx());
        let mut custom_redeem_request = lst_info.custom_redeem_request(
            lst_to_unstake,
            &mut system_state,
            runner.ctx(),
        );
        weight_hook.handle_custom_redeem_request(
            &mut system_state,
            &mut lst_info,
            &mut custom_redeem_request,
            runner.ctx(),
        );

        assert!(
            lst_info.storage().validators().borrow(0).total_sui_amount() == 25 * MIST_PER_SUI - 2_500_000_000,
        );
        assert!(
            lst_info.storage().validators().borrow(1).total_sui_amount() == 75 * MIST_PER_SUI - 7_500_000_000,
        );

        let sui = lst_info.custom_redeem(
            custom_redeem_request,
            &mut system_state,
            runner.ctx(),
        );
        assert!(sui.value() == 10 * MIST_PER_SUI - 100_000_000); // 0.1 sui fee

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(weight_hook);
        std::unit_test::destroy(weight_hook_admin_cap);
        std::unit_test::destroy(lst_info);
        std::unit_test::destroy(lst);
        std::unit_test::destroy(sui);

        runner.finish();
    }
}
