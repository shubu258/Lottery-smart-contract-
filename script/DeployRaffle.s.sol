//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/interaction.s.sol";


contract DeployRaffle is Script {
    function run() external{}

    function deployContract() public returns (Raffle, HelperConfig){
        HelperConfig helperConfig = new HelperConfig();
        //local -> deploy mocks, get local config 
        //sepolia -> get sepolia config 
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subscriptionId == 0){
            //create subscription 
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId,config.vrfCoordinator)=
                createSubscription.createSubscription(config.vrfCoordinator, config.account);

                //fund me 
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(config.entranceFee,
        config.interval,
        config.vrfCoordinator,
        config.gasLane,
        config.subscriptionId,
        config.callbackGasLimit

        );
        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        // dont need to broadcast ......... 
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account); 
        return(raffle, helperConfig);

    }
    

    //function deployContract() public returns(Raffle, HelpConfig){}
}