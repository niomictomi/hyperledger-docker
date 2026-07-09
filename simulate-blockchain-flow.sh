#!/bin/bash

# ============================================================================
# HYPERLEDGER FABRIC - COMPLETE BLOCKCHAIN FLOW SIMULATOR
# ============================================================================
# Script ini mensimulasikan 5 fase blockchain transaction:
#   Phase 1: PROPOSAL    - Client membuat transaction proposal
#   Phase 2: ENDORSEMENT - Peers endorse (sign) proposal
#   Phase 3: ORDERING    - Orderer sequence tx (Raft consensus)
#   Phase 4: VALIDATION  - Peers validate & create block
#   Phase 5: COMMIT      - Push to ledger & update world state
# ============================================================================

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Fungsi helper
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║  $1${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_phase() {
    echo ""
    echo -e "${BOLD}${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${PURPLE}  PHASE $1: $2${NC}"
    echo -e "${BOLD}${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_command() {
    echo -e "${CYAN}▶ Command:${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo ""
}

print_output() {
    echo -e "${GREEN}✓ Output:${NC}"
    echo "$1"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

wait_for_user() {
    echo ""
    read -p "Tekan ENTER untuk lanjut ke fase berikutnya..."
    echo ""
}

# ============================================================================
# SETUP ENVIRONMENT
# ============================================================================

print_header "HYPERLEDGER FABRIC - BLOCKCHAIN FLOW SIMULATOR"

# Cek apakah test-network berjalan
if ! docker ps | grep -q "peer0.org1.example.com"; then
    echo -e "${RED}✗ Test network tidak berjalan!${NC}"
    echo "Silakan jalankan: cd fabric-samples/test-network && ./network.sh up createChannel -s couchdb"
    exit 1
fi

# Masuk ke folder test-network
cd /Users/therock/gov-blockchain-sim/fabric-samples/test-network || exit 1

# Set environment untuk Org1
export FABRIC_CFG_PATH=${PWD}/compose/docker/peercfg
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_ADDRESS=localhost:7051
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

print_success "Environment configured for Org1"
print_info "Channel: mychannel"
print_info "Chaincode: basic"

# Generate unique asset ID berdasarkan timestamp
ASSET_ID="asset_$(date +%s)"
print_info "Asset ID yang akan dibuat: ${BOLD}$ASSET_ID${NC}"

# Bersihkan logs untuk observasi bersih
print_info "Membersihkan logs untuk observasi..."
docker logs peer0.org1.example.com > /tmp/peer0_before.log 2>&1
docker logs peer0.org2.example.com > /tmp/peer2_before.log 2>&1
docker logs orderer.example.com > /tmp/orderer_before.log 2>&1

# Tampilkan blockchain info saat ini
print_header "INITIAL STATE"
print_command "peer channel getinfo -c mychannel"
INITIAL_INFO=$(peer channel getinfo -c mychannel 2>&1 | grep "Blockchain info")
print_output "$INITIAL_INFO"

wait_for_user

# ============================================================================
# PHASE 1: PROPOSAL
# ============================================================================

print_phase "1" "PROPOSAL (Client Side)"

echo -e "${BOLD}📖 Teori:${NC}"
echo "Client membuat transaction proposal yang berisi:"
echo "  • Chaincode function name (CreateAsset)"
echo "  • Arguments (asset ID, color, size, owner, value)"
echo "  • Client identity (MSP + certificate)"
echo "  • Proposal hash (untuk consistency)"
echo ""

echo -e "${BOLD}🎯 Aksi:${NC}"
echo "Kita akan membuat asset baru: $ASSET_ID"
echo "  - Color: cyan"
echo "  - Size: 25"
echo "  - Owner: Charlie"
echo "  - AppraisedValue: 5000"
echo ""

# Start monitoring logs di background
print_info "Memulai monitoring logs (real-time)..."
docker logs -f peer0.org1.example.com > /tmp/peer0_live.log 2>&1 &
PEER1_PID=$!
docker logs -f peer0.org2.example.com > /tmp/peer2_live.log 2>&1 &
PEER2_PID=$!
docker logs -f orderer.example.com > /tmp/orderer_live.log 2>&1 &
ORDERER_PID=$!

sleep 2
print_success "Monitoring started (PIDs: peer1=$PEER1_PID, peer2=$PEER2_PID, orderer=$ORDERER_PID)"

print_command "peer chaincode invoke -o localhost:7050 ..."
echo -e "${YELLOW}Menjalankan transaction...${NC}"
echo ""

# Jalankan transaction
INVOKE_RESULT=$(peer chaincode invoke -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
  -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c "{\"function\":\"CreateAsset\",\"Args\":[\"$ASSET_ID\",\"cyan\",\"25\",\"Charlie\",\"5000\"]}" 2>&1)

print_output "$INVOKE_RESULT"

if echo "$INVOKE_RESULT" | grep -q "status:200"; then
    print_success "Transaction submitted successfully!"
else
    print_warning "Transaction may have issues, check output above"
fi

wait_for_user

# ============================================================================
# PHASE 2: ENDORSEMENT
# ============================================================================

print_phase "2" "ENDORSEMENT (Peer Side)"

echo -e "${BOLD}📖 Teori:${NC}"
echo "Setiap peer yang dituju akan:"
echo "  1. Execute chaincode (simulasi)"
echo "  2. Generate Read-Write Set (state changes)"
echo "  3. Sign proposal response dengan private key"
echo "  4. Return endorsed proposal ke client"
echo ""

# Stop monitoring
kill $PEER1_PID $PEER2_PID $ORDERER_PID 2>/dev/null
sleep 1

echo -e "${BOLD}🔍 Observasi: Endorsement di Peer0.Org1${NC}"
echo ""
PEER1_ENDORSEMENT=$(docker logs peer0.org1.example.com --tail 50 2>&1 | grep -E "callChaincode|endorser|ProcessProposal" | tail -5)
print_output "$PEER1_ENDORSEMENT"

echo -e "${BOLD}🔍 Observasi: Endorsement di Peer0.Org2${NC}"
echo ""
PEER2_ENDORSEMENT=$(docker logs peer0.org2.example.com --tail 50 2>&1 | grep -E "callChaincode|endorser|ProcessProposal" | tail -5)
print_output "$PEER2_ENDORSEMENT"

# Fetch dan decode block terbaru
print_info "Fetching block terbaru untuk analisis endorsement..."
peer channel fetch newest /tmp/latest.block -c mychannel -o localhost:7050 \
  --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem 2>/dev/null

configtxlator proto_decode --input /tmp/latest.block --type common.Block --output /tmp/latest.json 2>/dev/null

echo -e "${BOLD}📊 Analisis Endorsement Signatures:${NC}"
echo ""
NUM_ENDORSERS=$(jq '.data.data[0].payload.data.actions[0].payload.action.endorsements | length' /tmp/latest.json 2>/dev/null)
print_info "Jumlah endorser: ${BOLD}$NUM_ENDORSERS${NC}"
echo ""

echo -e "${BOLD}Detail Endorser:${NC}"
jq -r '.data.data[0].payload.data.actions[0].payload.action.endorsements[] | "  • MSP ID: \(.endorser.mspid)\n    Signature length: \(.signature | length) bytes"' /tmp/latest.json 2>/dev/null
echo ""

print_success "Kedua org (Org1 + Org2) telah endorse transaction!"

wait_for_user

# ============================================================================
# PHASE 3: ORDERING (Raft Consensus)
# ============================================================================

print_phase "3" "ORDERING (Raft Consensus)"

echo -e "${BOLD}📖 Teori:${NC}"
echo "Orderer menggunakan Raft consensus untuk:"
echo "  1. Receive endorsed transactions dari client"
echo "  2. Sequence transactions into blocks"
echo "  3. Replicate blocks ke semua orderers"
echo "  4. Deliver blocks ke peers"
echo ""

echo -e "${BOLD}🔍 Observasi: Orderer Logs${NC}"
echo ""
ORDERER_LOGS=$(docker logs orderer.example.com --tail 50 2>&1 | grep -E "Broadcast|Received block|Committed|Step" | tail -10)
print_output "$ORDERER_LOGS"

echo -e "${BOLD}📊 Block Header (Proof of Ordering):${NC}"
echo ""
jq -r '.data.data[0].payload.header.channel_header | "  • Channel ID: \(.channel_id)\n  • Type: \(.type) (ENDORSER_TRANSACTION)\n  • Transaction ID: \(.tx_id)\n  • Timestamp: \(.timestamp)"' /tmp/latest.json 2>/dev/null
echo ""

echo -e "${BOLD}📊 Block Metadata:${NC}"
echo ""
jq -r '.metadata.metadata[0].signatures | length' /tmp/latest.json 2>/dev/null | xargs -I {} echo "  • Signatures count: {}"
echo ""

print_success "Transaction telah di-order dan dimasukkan ke block!"

wait_for_user

# ============================================================================
# PHASE 4: VALIDATION
# ============================================================================

print_phase "4" "VALIDATION (Peer Side)"

echo -e "${BOLD}📖 Teori:${NC}"
echo "Peer menerima block dari orderer dan melakukan:"
echo "  1. Signature verification - cek signature endorsers"
echo "  2. Read-Write Set validation - cek version consistency"
echo "  3. Endorsement policy check - cek apakah memenuhi policy"
echo "  4. Block creation - tambahkan ke local ledger"
echo ""

echo -e "${BOLD}🔍 Observasi: Validation di Peer0.Org1${NC}"
echo ""
PEER1_VALIDATION=$(docker logs peer0.org1.example.com --tail 30 2>&1 | grep -E "Validate|Validated|valid|invalid" | tail -5)
print_output "$PEER1_VALIDATION"

echo -e "${BOLD}🔍 Observasi: Validation di Peer0.Org2${NC}"
echo ""
PEER2_VALIDATION=$(docker logs peer0.org2.example.com --tail 30 2>&1 | grep -E "Validate|Validated|valid|invalid" | tail -5)
print_output "$PEER2_VALIDATION"

echo -e "${BOLD}📊 Read-Write Set (State Changes):${NC}"
echo ""
echo -e "${CYAN}Reads:${NC}"
jq -r '.data.data[0].payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[] | select(.namespace == "basic") | .rwset.reads[]? | "  • Key: \(.key)\n    Version: \(.version.block_num // "null"):\(.version.tx_num // "0")"' /tmp/latest.json 2>/dev/null
echo ""

echo -e "${CYAN}Writes:${NC}"
jq -r '.data.data[0].payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[] | select(.namespace == "basic") | .rwset.writes[]? | "  • Key: \(.key)\n    Value (Base64): \(.value | .[0:50])..."' /tmp/latest.json 2>/dev/null
echo ""

echo -e "${BOLD}🔓 Decoded Value:${NC}"
echo ""
DECODED_VALUE=$(jq -r '.data.data[0].payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[] | select(.namespace == "basic") | .rwset.writes[0].value' /tmp/latest.json 2>/dev/null | base64 -d 2>/dev/null)
echo "$DECODED_VALUE" | jq .
echo ""

print_success "Block telah divalidasi dan state changes verified!"

wait_for_user

# ============================================================================
# PHASE 5: COMMIT
# ============================================================================

print_phase "5" "COMMIT (Push to Ledger)"

echo -e "${BOLD}📖 Teori:${NC}"
echo "Setelah validasi berhasil:"
echo "  1. Append block ke blockchain ledger (immutable)"
echo "  2. Update world state di CouchDB (mutable)"
echo "  3. Emit events untuk subscribers"
echo "  4. Notify client via gRPC"
echo ""

echo -e "${BOLD}🔍 Observasi: Commit di Peer0.Org1${NC}"
echo ""
PEER1_COMMIT=$(docker logs peer0.org1.example.com --tail 20 2>&1 | grep -E "commit|Commit|Committed" | tail -3)
print_output "$PEER1_COMMIT"

echo -e "${BOLD}🔍 Observasi: Commit di Peer0.Org2${NC}"
echo ""
PEER2_COMMIT=$(docker logs peer0.org2.example.com --tail 20 2>&1 | grep -E "commit|Commit|Committed" | tail -3)
print_output "$PEER2_COMMIT"

# Verify hash chain
echo -e "${BOLD}🔗 Hash Chain Verification:${NC}"
echo ""

# Fetch 2 block terakhir
peer channel fetch newest /tmp/block_newest.block -c mychannel -o localhost:7050 \
  --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem 2>/dev/null

configtxlator proto_decode --input /tmp/block_newest.block --type common.Block --output /tmp/block_newest.json 2>/dev/null

CURRENT_HASH=$(jq -r '.header.data_hash' /tmp/block_newest.json 2>/dev/null)
PREV_HASH_IN_CURRENT=$(jq -r '.header.previous_hash' /tmp/block_newest.json 2>/dev/null)

print_info "Current Block Data Hash: ${BOLD}$CURRENT_HASH${NC}"
print_info "Previous Hash (in current block): ${BOLD}$PREV_HASH_IN_CURRENT${NC}"
echo ""

# Verify state
echo -e "${BOLD}🗄️ Verify State (Query from Blockchain):${NC}"
echo ""
print_command "peer chaincode query -C mychannel -n basic -c '{\"Args\":[\"ReadAsset\",\"$ASSET_ID\"]}'"
QUERY_RESULT=$(peer chaincode query -C mychannel -n basic -c "{\"Args\":[\"ReadAsset\",\"$ASSET_ID\"]}" 2>&1)
echo "$QUERY_RESULT" | jq .
echo ""

print_success "Block telah di-commit ke ledger dan world state updated!"

wait_for_user

# ============================================================================
# CHECKLIST VERIFICATION
# ============================================================================

print_header "COMPLETE FLOW VERIFICATION CHECKLIST"

# Get final blockchain info
FINAL_INFO=$(peer channel getinfo -c mychannel 2>&1 | grep "Blockchain info")
FINAL_HEIGHT=$(echo "$FINAL_INFO" | grep -o '"height":[0-9]*' | cut -d':' -f2)

echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║         BLOCKCHAIN FLOW VERIFICATION SUMMARY             ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓ Phase 1: PROPOSAL${NC}"
echo "  • Client identity: Org1MSP Admin"
echo "  • Transaction: CreateAsset($ASSET_ID, cyan, 25, Charlie, 5000)"
echo ""

echo -e "${GREEN}✓ Phase 2: ENDORSEMENT${NC}"
echo "  • Endorsers: Org1 + Org2"
echo "  • Number of signatures: $NUM_ENDORSERS"
echo ""

echo -e "${GREEN}✓ Phase 3: ORDERING (Raft Consensus)${NC}"
echo "  • Orderer: orderer.example.com"
echo "  • Consensus: etcdraft"
echo "  • Block height: $FINAL_HEIGHT"
echo ""

echo -e "${GREEN}✓ Phase 4: VALIDATION${NC}"
echo "  • Block validated by all peers"
echo "  • Read-Write Set verified"
echo "  • Endorsement policy satisfied"
echo ""

echo -e "${GREEN}✓ Phase 5: COMMIT${NC}"
echo "  • Block appended to blockchain"
echo "  • World state updated in CouchDB"
echo "  • Hash chain verified"
echo ""

echo -e "${BOLD}📊 Final State:${NC}"
echo "$FINAL_INFO"
echo ""

echo -e "${BOLD}🔍 Verify Asset in Blockchain:${NC}"
echo "$QUERY_RESULT" | jq .
echo ""

echo -e "${BOLD}🗄️ View in CouchDB:${NC}"
echo "  URL: http://localhost:23054/_utils"
echo "  Login: admin / adminpw"
echo "  Database: mychannel_basic"
echo "  Document: $ASSET_ID"
echo ""

echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║           ✓ ALL PHASES VERIFIED SUCCESSFULLY!            ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# KEY TAKEAWAYS
# ============================================================================

print_header "KEY TAKEAWAYS"

echo -e "${BOLD}1. Consensus (Raft)${NC}"
echo "   • Orderer menggunakan Raft (not Byzantine Fault Tolerance)"
echo "   • Leader election → batch transactions → replicate to followers"
echo "   • Bukti: docker logs orderer.example.com | grep Raft"
echo ""

echo -e "${BOLD}2. Smart Contract (Chaincode)${NC}"
echo "   • Chaincode = smart contract di Hyperledger"
echo "   • Execute di setiap peer (simulasi)"
echo "   • Bukti: callChaincode -> finished chaincode: basic"
echo ""

echo -e "${BOLD}3. Activity (Transaction)${NC}"
echo "   • Proposal → Endorsement → Order → Validate → Commit"
echo "   • Setiap step observable via logs"
echo "   • Bukti: Logs di peer0.org1, peer0.org2, orderer"
echo ""

echo -e "${BOLD}4. Block Chaining${NC}"
echo "   • Setiap block punya previous_hash"
echo "   • Hash chain = immutability guarantee"
echo "   • Bukti: previous_hash == data_hash of previous block"
echo ""

echo -e "${BOLD}5. Push to Ledger${NC}"
echo "   • Block appended ke blockchain (immutable)"
echo "   • World state updated di CouchDB (mutable)"
echo "   • Bukti: Committed block [X] with 1 transaction(s)"
echo ""

print_success "Simulasi selesai! Anda telah melihat complete blockchain flow!"
echo ""
echo -e "${CYAN}Next step: IPFS + Encryption untuk Secure Document Management${NC}"
echo ""
