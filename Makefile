-include .env 

.PHONY : all test deploy 

build :; forge build 

test: 
forge test 

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install 
smartcontract/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/ 
forge-std@1.8.2 --o-commit && forge install transmission11/solmate@v6 --no-commit 

deploy-sepolia:
  @forge script scripts/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL)
  --account default --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv