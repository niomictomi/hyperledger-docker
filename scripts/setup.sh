#!/bin/bash

set -e

echo "=========================================="
echo "GOV-BLOCKCHAIN-SIM: Setup Script"
echo "=========================================="

# Set PATH
export PATH=$PATH:$PWD/bin

# Step 1: Generate Crypto Material
echo ""
echo "[1/5] Generating crypto material..."
./bin/cryptogen generate \
  --config=./config/crypto-config.yaml \
  --output=./organizations

echo "✓ Crypto material generated"
ls -la organizations/

# Step 2: Generate Channel Block
echo ""
echo "[2/5] Generating channel block..."
export FABRIC_CFG_PATH=$PWD/config
mkdir -p channel-artifacts

./bin/configtxgen -profile GovChannel \
  -outputBlock ./channel-artifacts/mychannel.block \
  -channelID mychannel

echo "✓ Channel block generated"
ls -la channel-artifacts/

# Step 3: Start Network
echo ""
echo "[3/5] Starting network..."
cd network
docker-compose up -d
cd ..

echo "✓ Network started"
docker ps

# Step 4: Join Channel to Orderer
echo ""
echo "[4/5] Joining channel to orderer..."
sleep 5
./bin/osnadmin channel join --channelID mychannel \
  --config-block ./channel-artifacts/mychannel.block \
  -o localhost:7053

echo "✓ Channel joined to orderer"

# Step 5: Join Peers to Channel
echo ""
echo "[5/5] Joining peers to channel..."
docker exec -it cli bash -c "
  peer channel join -b ./channel-artifacts/mychannel.block
  
  export CORE_PEER_ADDRESS=peer1.org1.example.com:8051
  peer channel join -b ./channel-artifacts/mychannel.block
  
  export CORE_PEER_LOCALMSPID=Org2MSP
  export CORE_PEER_ADDRESS=peer0.org2.example.com:9051
  export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  peer channel join -b ./channel-artifacts/mychannel.block
  
  export CORE_PEER_ADDRESS=peer1.org2.example.com:10051
  export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  peer channel join -b ./channel-artifacts/mychannel.block
  
  echo '✓ All peers joined channel'
  peer channel list
"

echo ""
echo "=========================================="
echo "✓ SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Deploy chaincode: docker exec -it cli bash"
echo "2. Test IPFS: curl http://localhost:5001/api/v0/id"
echo "3. View CouchDB: http://localhost:5984/_utils"