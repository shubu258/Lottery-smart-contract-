//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
//forge install smartcontractkit/chainlink-brownie-contracts --no-commit
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
//import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
//import {console} from "forge-std/console.sol";

/**
 * @title A sample Raffle Contract
 * @author shivansh nigam
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2 and Chainlink Automation
 */

// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract
// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions

// external & public view & pure functions

contract Raffle is VRFConsumerBaseV2Plus {
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    error Raffle_NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);
    // event EnteredRaffle(address indexed player);

    // type declaration
    enum RaffleState{
        OPEN, //0
        CALCULATING //1

    }


    //state variable 
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint256 private s_lastTimeStamp;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    

    //address immutable i_vrfCoordinator;
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //console.log("HELLO!!");
       // console.log(msg.value);
        //require(msg.value >= i_entranceFee, "Not Enough ETH Sent");
        if (msg.value < i_entranceFee){
            revert Raffle__SendMoreToEnterRaffle();
        }
        if(s_raffleState != RaffleState.OPEN){
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }



    /**@dev this is the function that the chainlink nodes will call to see
     * if the lottery to have the winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. the lottery is open 
     * 3. the contract has ETH
     * 4. Implicity, your subscription has LINK 
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery 
     * @return - ignored 
     */


    function checkUpkeep(bytes memory /*check data */) public 
    view 
    returns (bool upkeepNeeded, bytes memory /* performData */) 
    { 
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;    
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return(upkeepNeeded, "");
    }

    // when should the winner be picked

    
    function performUpkeep(bytes calldata /* performData */) external {
        //check to see that enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        //function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {}

        // uint256 requestId = s_vrfCoordinator.requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash, // keyHash
            subId: i_subscriptionId, // subId
            requestConfirmations: REQUEST_CONFIRMATIONS, // requestConfirmations
            callbackGasLimit: i_callbackGasLimit, // callbackGasLimit
            numWords: NUM_WORDS, // numWords
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false}) // nativePayment = false
            )
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }
     // CEI: Checks , Effects , Intreactions pattern 
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal override {
        //checks 
        //conditions


        
        // s_player = 10
        // rng = 12 
        // 12 % 10 = 2 <-
        // 2354346346574568857896789890 
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

         //Interactions(External Contract Interactions )
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if(!success){
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(s_recentWinner);

    }

    // Closing the requestRandomWords function call

    // getter function

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState){
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    }

        function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;

    }
}
