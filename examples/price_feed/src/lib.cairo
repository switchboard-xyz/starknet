// The contract that updates the BTC/USD price feed on the Switchboard contract and reads the updated value.

#[starknet::interface]
pub trait IBtcFeedContract<T> {
    fn update(
        ref self: T, update_data: ByteArray
    );
}
 
#[starknet::contract]
mod example_contract {
    use core::{ByteArray, panic_with_felt252};
    use starknet::{ContractAddress, get_block_timestamp};
    use switchboard::{ISwitchboardDispatcher, ISwitchboardDispatcherTrait};

    // Storage for the Switchboard contract addresss, the BTC Feed ID, and the BTC price.
    #[storage]
    struct Storage {
        switchboard_address: ContractAddress,
        btc_feed_id: felt252,
        btc_price: i128,
    }
 
    // Constructor to initialize the contract storage.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        switchboard_address: ContractAddress,
        btc_feed_id: felt252
    ) {
        self.switchboard_address.write(switchboard_address);
        self.btc_feed_id.write(btc_feed_id);
    }
 
    #[abi(embed_v0)]
    impl BtcFeedContract of super::IBtcFeedContract<ContractState> {
        fn update(
            ref self: ContractState,
            update_data: ByteArray
        ) {
            let switchboard = ISwitchboardDispatcher { contract_address: self.switchboard_address.read() };

            // update the price feed
            switchboard.update_feed_data(update_data);

            // read the price feed
            let btc_price = switchboard.latest_result(self.btc_feed_id.read());

            // check the age of the update - if it is older than 120 seconds, panic
            if (btc_price.max_timestamp < get_block_timestamp() - 120) {
                panic_with_felt252('Price feed is too old');
            }

            // write the price to storage
            self.btc_price.write(btc_price.result);
            
        }
    }
}