cd /Users/therock/gov-blockchain-sim/fabric-samples/test-network
./network.sh down
./network.sh up createChannel -s couchdb
./network.sh deployCC -ccn basic -ccp ../asset-transfer-basic/chaincode-go -ccl go