#[test_only]
module liquid_staking::test_utils {
    use sui_system::{test_runner::{Self, TestRunner}, validator_builder};

    public fun advance_epoch_no_rewards(runner: &mut TestRunner) {
        runner.advance_epoch(option::none()).destroy_for_testing();
    }

    public fun advance_epoch_with_rewards(runner: &mut TestRunner, computation_charge: u64) {
        let opts = runner.advance_epoch_opts().computation_charge(computation_charge);
        runner.advance_epoch(option::some(opts)).destroy_for_testing();
    }

    public fun setup_runner(stakes: vector<u64>): TestRunner {
        let mut runner = test_runner::new()
            .validators(stakes.map!(|stake| validator_builder::new().initial_stake(stake)))
            .build();

        advance_epoch_no_rewards(&mut runner);

        runner
    }
}
