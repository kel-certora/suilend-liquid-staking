#[test_only]
module liquid_staking::liquid_staking_tests {
    use liquid_staking::{
        fees,
        liquid_staking::{create_lst, create_lst_with_stake},
        test_utils::{advance_epoch_no_rewards, advance_epoch_with_rewards, setup_runner}
    };
    use sui::{coin, sui::SUI, test_scenario};
    use sui_system::sui_system::SuiSystemState;

    /* Constants */
    const MIST_PER_SUI: u64 = 1_000_000_000;

    public struct TEST has drop {}

    #[test]
    fun test_create_lst() {
        let mut runner = setup_runner(vector[100, 100]);

        runner.scenario_mut().next_tx(@0x0);

        let system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let (admin_cap, lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        assert!(lst_info.total_lst_supply() == 0);
        assert!(lst_info.storage().total_sui_supply() == 0);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    fun test_create_lst_with_stake_happy() {
        let mut runner = setup_runner(vector[100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        let staked_sui = runner.stake_with_and_take(validator_addresses[0], 100);

        advance_epoch_no_rewards(&mut runner);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let fungible_staked_sui = system_state.convert_to_fungible_staked_sui(
            staked_sui,
            runner.ctx(),
        );

        // Create a treasury cap with non-zero coins
        let mut treasury_cap = coin::create_treasury_cap_for_testing<TEST>(runner.ctx());
        let coins = treasury_cap.mint(200 * MIST_PER_SUI, runner.ctx());

        let (admin_cap, lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            treasury_cap,
            vector[fungible_staked_sui],
            coin::mint_for_testing(100 * MIST_PER_SUI, runner.ctx()),
            runner.ctx(),
        );

        assert!(lst_info.total_lst_supply() == 200 * MIST_PER_SUI);
        assert!(lst_info.storage().total_sui_supply() == 200 * MIST_PER_SUI);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);
        std::unit_test::destroy(coins);

        runner.finish();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = liquid_staking::liquid_staking)]
    fun test_create_lst_fail() {
        let mut runner = setup_runner(vector[100, 100]);

        let system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let mut treasury_cap = coin::create_treasury_cap_for_testing(runner.ctx());
        let coins = treasury_cap.mint(1000 * MIST_PER_SUI, runner.ctx());

        let (admin_cap, lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            treasury_cap,
            runner.ctx(),
        );

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(coins);
        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = liquid_staking::liquid_staking)]
    fun test_create_lst_with_stake_fail_1() {
        let mut runner = setup_runner(vector[100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        let staked_sui = runner.stake_with_and_take(validator_addresses[0], 100);

        advance_epoch_no_rewards(&mut runner);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let fungible_staked_sui = system_state.convert_to_fungible_staked_sui(
            staked_sui,
            runner.ctx(),
        );

        // Create an empty treasury cap
        let treasury_cap = coin::create_treasury_cap_for_testing(runner.ctx());

        let (admin_cap, lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            treasury_cap,
            vector[fungible_staked_sui],
            coin::zero<SUI>(runner.ctx()),
            runner.ctx(),
        );

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = liquid_staking::liquid_staking)]
    fun test_create_lst_with_stake_fail_2() {
        let mut runner = setup_runner(vector[100, 100]);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let mut treasury_cap = coin::create_treasury_cap_for_testing(runner.ctx());
        let coins = treasury_cap.mint(1000 * MIST_PER_SUI, runner.ctx());

        let (admin_cap, lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            treasury_cap,
            vector::empty(),
            coin::zero<SUI>(runner.ctx()),
            runner.ctx(),
        );

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);
        std::unit_test::destroy(coins);

        runner.finish();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = liquid_staking::liquid_staking)]
    fun test_create_lst_with_stake_fail_3() {
        let mut runner = setup_runner(vector[100, 100]);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let mut treasury_cap = coin::create_treasury_cap_for_testing(runner.ctx());
        let coins = treasury_cap.mint(1000 * MIST_PER_SUI, runner.ctx());

        let (admin_cap, lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            treasury_cap,
            vector::empty(),
            coin::mint_for_testing(1000  * MIST_PER_SUI - 1, runner.ctx()),
            runner.ctx(),
        );

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);
        std::unit_test::destroy(coins);

        runner.finish();
    }

    #[test]
    #[expected_failure(abort_code = 0, location = liquid_staking::liquid_staking)]
    fun test_create_lst_with_stake_fail_4() {
        let mut runner = setup_runner(vector[100, 100]);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let mut treasury_cap = coin::create_treasury_cap_for_testing(runner.ctx());
        let coins = treasury_cap.mint(1000 * MIST_PER_SUI, runner.ctx());

        let (admin_cap, lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            treasury_cap,
            vector::empty(),
            coin::mint_for_testing(2000  * MIST_PER_SUI + 1, runner.ctx()),
            runner.ctx(),
        );

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);
        std::unit_test::destroy(coins);

        runner.finish();
    }

    #[test]
    fun test_mint_and_redeem() {
        let mut runner = setup_runner(vector[100, 100]);

        runner.scenario_mut().next_tx(@0x0);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let sui = coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, runner.ctx());

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        let lst = lst_info.mint(&mut system_state, sui, runner.ctx());

        assert!(lst.value() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_lst_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.fees() == MIST_PER_SUI);
        std::unit_test::destroy(lst);

        let sui = coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, runner.ctx());
        let mut lst = lst_info.mint(&mut system_state, sui, runner.ctx());

        assert!(lst.value() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_lst_supply() == 198 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 198 * MIST_PER_SUI);
        assert!(lst_info.fees() == 2 * MIST_PER_SUI);

        let sui = lst_info.redeem(
            lst.split(10 * MIST_PER_SUI, runner.ctx()),
            &mut system_state,
            runner.ctx(),
        );

        assert!(sui.value() ==  9_900_000_000);
        assert!(lst_info.total_lst_supply() == 188 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 188 * MIST_PER_SUI);
        assert!(lst_info.fees() == 2 * MIST_PER_SUI + 100_000_000);

        std::unit_test::destroy(sui);
        std::unit_test::destroy(lst);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    fun test_increase_and_decrease_validator_stake() {
        let mut runner = setup_runner(vector[10, 10]);
        let validator_addresses = runner.genesis_validator_addresses();

        runner.scenario_mut().next_tx(@0x0);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let sui = coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, runner.ctx());

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        let lst = lst_info.mint(&mut system_state, sui, runner.ctx());

        assert!(lst.value() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_lst_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.fees() == MIST_PER_SUI);

        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[0],
            20 * MIST_PER_SUI,
            runner.ctx(),
        );

        assert!(lst_info.total_lst_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 99 * MIST_PER_SUI);
        assert!(
            lst_info.storage().validators()[0].inactive_stake().borrow().staked_sui_amount() == 20 * MIST_PER_SUI,
        );

        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[1],
            20 * MIST_PER_SUI,
            runner.ctx(),
        );

        assert!(lst_info.total_lst_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 99 * MIST_PER_SUI);
        assert!(
            lst_info.storage().validators()[1].inactive_stake().borrow().staked_sui_amount() == 20 * MIST_PER_SUI,
        );

        test_scenario::return_shared(system_state);

        advance_epoch_with_rewards(&mut runner, 20);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[1],
            20 * MIST_PER_SUI,
            runner.ctx(),
        );

        assert!(lst_info.total_lst_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 99 * MIST_PER_SUI);
        assert!(
            lst_info.storage().validators()[1].inactive_stake().borrow().staked_sui_amount() == 20 * MIST_PER_SUI,
        );
        assert!(
            lst_info.storage().validators()[1].active_stake().borrow().value() == 10 * MIST_PER_SUI,
        );

        lst_info.decrease_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[1],
            40 * MIST_PER_SUI,
            runner.ctx(),
        );

        assert!(lst_info.total_lst_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 99 * MIST_PER_SUI);
        assert!(lst_info.storage().validators()[1].inactive_stake().is_none());
        assert!(lst_info.storage().validators()[1].active_stake().is_none());

        std::unit_test::destroy(lst);
        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    fun test_spread_fee() {
        let mut runner = setup_runner(vector[90, 90]);
        let validator_addresses = runner.genesis_validator_addresses();

        runner.scenario_mut().next_tx(@0x0);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_spread_fee_bps(5000) // 50%
                .set_sui_mint_fee_bps(1000) // 10%
                .to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        let sui = coin::mint_for_testing<SUI>(100 * MIST_PER_SUI, runner.ctx());
        let lst = lst_info.mint(&mut system_state, sui, runner.ctx());

        assert!(lst.value() == 90 * MIST_PER_SUI);

        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[0],
            45 * MIST_PER_SUI,
            runner.ctx(),
        );
        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[1],
            45 * MIST_PER_SUI,
            runner.ctx(),
        );

        test_scenario::return_shared(system_state);

        advance_epoch_no_rewards(&mut runner);

        // got 90 SUI of rewards, 45 of that should be spread fee
        advance_epoch_with_rewards(&mut runner, 270);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let sui = lst_info.redeem(
            lst,
            &mut system_state,
            runner.ctx(),
        );

        assert!(sui.value() == 135 * MIST_PER_SUI);
        assert!(lst_info.storage().total_sui_supply() == 45 * MIST_PER_SUI);
        assert!(lst_info.total_sui_supply() == 0);
        assert!(lst_info.accrued_spread_fees() == 45 * MIST_PER_SUI);

        let fees = lst_info.collect_fees(&mut system_state, &admin_cap, runner.ctx());
        assert!(fees.value() == 55 * MIST_PER_SUI); // 45 in spread, 10 in mint
        assert!(lst_info.accrued_spread_fees() == 0);
        assert!(lst_info.storage().total_sui_supply() == 0);

        std::unit_test::destroy(sui);
        std::unit_test::destroy(fees);
        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    fun test_update_fees() {
        let mut runner = setup_runner(vector[90, 90]);

        runner.scenario_mut().next_tx(@0x0);

        let system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_spread_fee_bps(5000) // 50%
                .set_sui_mint_fee_bps(1000) // 10%
                .to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        lst_info.update_fees(
            &admin_cap,
            fees::new_builder(runner.ctx())
                .set_spread_fee_bps(1000) // 10%
                .set_sui_mint_fee_bps(100) // 10%
                .to_fee_config(),
        );

        assert!(lst_info.fee_config().spread_fee_bps() == 1000);
        assert!(lst_info.fee_config().sui_mint_fee_bps() == 100);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    fun test_increase_validator_stake_by_dust_amount() {
        let mut runner = setup_runner(vector[100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        runner.scenario_mut().next_tx(@0x0);

        let mut treasury_cap = coin::create_treasury_cap_for_testing<TEST>(runner.ctx());
        let lst = treasury_cap.mint(100 * MIST_PER_SUI, runner.ctx());

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let (admin_cap, mut lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_spread_fee_bps(5000) // 50%
                .set_sui_mint_fee_bps(1000) // 10%
                .to_fee_config(),
            treasury_cap,
            vector::empty(),
            coin::mint_for_testing(100 * MIST_PER_SUI, runner.ctx()),
            runner.ctx(),
        );

        let increased_amount = lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[0],
            MIST_PER_SUI - 1,
            runner.ctx(),
        );

        assert!(increased_amount == 0);

        std::unit_test::destroy(lst);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    fun test_change_validator_priority() {
        let mut runner = setup_runner(vector[100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        runner.scenario_mut().next_tx(@0x0);

        let mut treasury_cap = coin::create_treasury_cap_for_testing<TEST>(runner.ctx());
        let lst = treasury_cap.mint(100 * MIST_PER_SUI, runner.ctx());

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let pool_id_1 = system_state.validator_staking_pool_id(validator_addresses[0]);
        let pool_id_2 = system_state.validator_staking_pool_id(validator_addresses[1]);

        let (admin_cap, mut lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_spread_fee_bps(5000) // 50%
                .set_sui_mint_fee_bps(1000) // 10%
                .to_fee_config(),
            treasury_cap,
            vector::empty(),
            coin::mint_for_testing(100 * MIST_PER_SUI, runner.ctx()),
            runner.ctx(),
        );

        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[0],
            MIST_PER_SUI,
            runner.ctx(),
        );

        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[1],
            MIST_PER_SUI,
            runner.ctx(),
        );

        assert!(lst_info.storage().validators()[0].staking_pool_id() == pool_id_1);
        assert!(lst_info.storage().validators()[1].staking_pool_id() == pool_id_2);

        lst_info.change_validator_priority(
            &admin_cap,
            0,
            1,
        );

        assert!(lst_info.storage().validators()[0].staking_pool_id() == pool_id_2);
        assert!(lst_info.storage().validators()[1].staking_pool_id() == pool_id_1);

        lst_info.change_validator_priority(
            &admin_cap,
            0,
            0,
        );

        assert!(lst_info.storage().validators()[0].staking_pool_id() == pool_id_2);
        assert!(lst_info.storage().validators()[1].staking_pool_id() == pool_id_1);

        std::unit_test::destroy(lst);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    /* randomized testing */

    #[random_test]
    fun test_random_increase_validator_stake(mint_amount: u64, stake_amount: u64) {
        let mut runner = setup_runner(vector[100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        runner.scenario_mut().next_tx(@0x0);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_spread_fee_bps(5000) // 50%
                .set_sui_mint_fee_bps(1000) // 10%
                .to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        let sui = coin::mint_for_testing<SUI>(mint_amount, runner.ctx());
        let lst = lst_info.mint(&mut system_state, sui, runner.ctx());
        let total_sui_supply = lst_info.total_sui_supply();

        let increased_amount = lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[0],
            stake_amount,
            runner.ctx(),
        );

        assert!(increased_amount == std::u64::min(total_sui_supply, stake_amount));

        std::unit_test::destroy(lst);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[random_test]
    fun test_random_decrease_validator_stake(mint_amount: u64, unstake_amount: u64) {
        let mut runner = setup_runner(vector[100, 100]);
        let validator_addresses = runner.genesis_validator_addresses();

        let staked_sui = runner.stake_with_and_take(
            validator_addresses[0],
            std::u64::max(mint_amount / MIST_PER_SUI, 1),
        );
        let mut treasury_cap = coin::create_treasury_cap_for_testing<TEST>(runner.ctx());
        let lst = treasury_cap.mint(mint_amount / MIST_PER_SUI * MIST_PER_SUI, runner.ctx());

        advance_epoch_no_rewards(&mut runner);

        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        let fungible_staked_sui = system_state.convert_to_fungible_staked_sui(
            staked_sui,
            runner.ctx(),
        );

        let (admin_cap, mut lst_info) = create_lst_with_stake<TEST>(
            &mut system_state,
            fees::new_builder(runner.ctx())
                .set_spread_fee_bps(5000) // 50%
                .set_sui_mint_fee_bps(1000) // 10%
                .to_fee_config(),
            treasury_cap,
            vector[fungible_staked_sui],
            coin::zero<SUI>(runner.ctx()),
            runner.ctx(),
        );

        let total_sui_supply = lst_info.total_sui_supply();

        let unstaked_amount = lst_info.decrease_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[0],
            unstake_amount,
            runner.ctx(),
        );

        assert!(unstaked_amount <= std::u64::min(total_sui_supply, unstake_amount + MIST_PER_SUI));

        std::unit_test::destroy(lst);

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(admin_cap);
        std::unit_test::destroy(lst_info);

        runner.finish();
    }

    #[test]
    #[expected_failure(abort_code = 6, location = liquid_staking::liquid_staking)]
    fun test_custom_redeem_request_fail_not_processed() {
        let mut runner = setup_runner(vector[100, 100, 100]);

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

        let lst_to_unstake = lst.split(10 * MIST_PER_SUI, runner.ctx());
        let custom_redeem_request = lst_info.custom_redeem_request(
            lst_to_unstake,
            &mut system_state,
            runner.ctx(),
        );

        let sui = lst_info.custom_redeem(custom_redeem_request, &mut system_state, runner.ctx());

        test_scenario::return_shared(system_state);

        std::unit_test::destroy(lst_info);
        std::unit_test::destroy(lst);
        std::unit_test::destroy(sui);
        std::unit_test::destroy(admin_cap);

        runner.finish();
    }

    #[test]
    fun test_exchange_rate_gap() {
        use sui_system::sui_system;
        use std::unit_test;

        let mut runner = setup_runner(vector[100]);
        let validator_addresses = runner.genesis_validator_addresses();

        // activate validator
        runner.scenario_mut().next_tx(@0x0);
        let mut system_state = runner.scenario_mut().take_shared<SuiSystemState>();
        sui_system::set_epoch_for_testing(&mut system_state, runner.ctx().epoch() + 1);
        runner.scenario_mut().next_epoch(@0x0);

        let (admin_cap, mut lst_info) = create_lst<TEST>(
            fees::new_builder(runner.ctx())
                .set_sui_mint_fee_bps(100)
                .set_redeem_fee_bps(100)
                .to_fee_config(),
            coin::create_treasury_cap_for_testing(runner.ctx()),
            runner.ctx(),
        );

        assert!(lst_info.total_lst_supply() == 0);
        assert!(lst_info.storage().total_sui_supply() == 0);

        let sui = coin::mint_for_testing<SUI>(200 * MIST_PER_SUI, runner.ctx());
        let lst = lst_info.mint(&mut system_state, sui, runner.ctx());

        lst_info.increase_validator_stake(
            &admin_cap,
            &mut system_state,
            validator_addresses[0],
            200 * MIST_PER_SUI,
            runner.ctx(),
        );

        test_scenario::return_shared(system_state);
        unit_test::destroy(admin_cap);
        unit_test::destroy(lst);
        unit_test::destroy(lst_info);

        runner.finish();
    }
}
