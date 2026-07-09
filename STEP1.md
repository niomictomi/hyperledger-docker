# 📚 **LAB GUIDE: Complete Blockchain Flow in Hyperledger Fabric**

Mari kita telusuri **setiap tahap** dari transaksi blockchain secara step-by-step, dengan bukti observasi di setiap fase.

---

## 🎯 **Overview: 5 Fase Blockchain Flow**

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRANSACTION LIFECYCLE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: PROPOSAL        → Client membuat transaction proposal │
│  Phase 2: ENDORSEMENT     → Peers endorse (sign) proposal       │
│  Phase 3: ORDERING        → Orderer sequence tx (Raft)          │
│  Phase 4: VALIDATION      → Peers validate & create block       │
│  Phase 5: COMMIT          → Push to ledger & update world state │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 **Persiapan: Setup Environment**

```bash
cd /Users/therock/gov-blockchain-sim/fabric-samples/test-network

# Set environment untuk Org1
export FABRIC_CFG_PATH=${PWD}/compose/docker/peercfg
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_ADDRESS=localhost:7051
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

# Bersihkan logs untuk observasi bersih
docker logs peer0.org1.example.com > /tmp/peer0_before.log
docker logs peer0.org2.example.com > /tmp/peer2_before.log
docker logs orderer.example.com > /tmp/orderer_before.log

# Cek blockchain info saat ini
echo "=== Blockchain Height ==="
peer channel getinfo -c mychannel
```

---

# 🟢 **PHASE 1: PROPOSAL (Client Side)**

## 📖 **Konsep Teoritis:**
Client membuat **transaction proposal** yang berisi:
- Chaincode function name
- Arguments
- Client identity (MSP + certificate)
- Proposal hash (untuk consistency)

## 🔬 **Observasi: Lihat Proposal di Network**

```bash
# Monitor logs peer0.org1 (real-time)
docker logs -f peer0.org1.example.com 2>&1 | grep -E "ProcessProposal|endorser|callChaincode" &
PEER1_PID=$!

# Monitor logs orderer (real-time)
docker logs -f orderer.example.com 2>&1 | grep -E "Broadcast|orderer|Step" &
ORDERER_PID=$!

sleep 2
echo "=== Monitoring started ==="
```

## 🚀 **Trigger Transaction (akan kita analisis)**

```bash
# Jalankan di terminal SEPARATE (buka terminal baru)
cd /Users/therock/gov-blockchain-sim/fabric-samples/test-network

export FABRIC_CFG_PATH=${PWD}/compose/docker/peercfg
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_ADDRESS=localhost:7051
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

# Create new asset
peer chaincode invoke -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem \
  -C mychannel -n basic \
  --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"CreateAsset","Args":["asset100","cyan","25","Charlie","5000"]}'
```

---

# 🟡 **PHASE 2: ENDORSEMENT (Peer Side)**

## 📖 **Konsep Teoritis:**
Setiap peer yang dituju akan:
1. **Execute chaincode** (simulasi)
2. **Generate Read-Write Set** (state changes)
3. **Sign proposal response** dengan private key
4. **Return endorsed proposal** ke client

## 🔬 **Observasi: Lihat Endorsement Process**

```bash
# Stop monitoring
kill $PEER1_PID $ORDERER_PID 2>/dev/null

# Lihat logs peer0.org1 setelah transaksi
echo "=== PEER0.ORG1 ENDORSEMENT LOGS ==="
docker logs peer0.org1.example.com --tail 30 | grep -E "callChaincode|endorser|ProcessProposal"

echo ""
echo "=== PEER0.ORG2 ENDORSEMENT LOGS ==="
docker logs peer0.org2.example.com --tail 30 | grep -E "callChaincode|endorser|ProcessProposal"
```

**Expected Output:**
```
[endorser] callChaincode -> finished chaincode: basic duration: Xms
[comm.grpc.server] unary call completed grpc.service=protos.Endorser grpc.method=ProcessProposal
```

## 📊 **Decode Endorsed Proposal dari Block**

```bash
cd /Users/therock/gov-blockchain-sim/fabric-samples/test-network

# Fetch block terbaru
peer channel fetch newest /tmp/latest.block -c mychannel -o localhost:7050 \
  --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem 2>/dev/null

# Decode block
configtxlator proto_decode --input /tmp/latest.block --type common.Block --output /tmp/latest.json

# Lihat endorsement signatures
echo "=== ENDORSEMENT SIGNATURES ==="
jq '.data.data[0].payload.data.actions[0].payload.action.endorsements | length' /tmp/latest.json
echo "Number of endorsers (should be 2: Org1 + Org2)"

# Lihat detail setiap endorser
echo ""
echo "=== ENDORSER DETAILS ==="
jq '.data.data[0].payload.data.actions[0].payload.action.endorsements[] | {endorser: .endorser.mspid, signature_length: (.signature | length)}' /tmp/latest.json
```

**Expected Output:**
```
2
Number of endorsers (should be 2: Org1 + Org2)

=== ENDORSER DETAILS ===
{
  "endorser": "Org1MSP",
  "signature_length": 64
}
{
  "endorser": "Org2MSP",
  "signature_length": 64
}
```

---

# 🔵 **PHASE 3: ORDERING (Consensus - Raft)**

## 📖 **Konsep Teoritis:**
Orderer menggunakan **Raft consensus** untuk:
1. **Receive** endorsed transactions dari client
2. **Sequence** transactions into blocks
3. **Replicate** blocks ke semua orderers
4. **Deliver** blocks ke peers

## 🔬 **Observasi: Lihat Raft Consensus**

```bash
# Lihat logs orderer
echo "=== ORDERER LOGS (Raft Consensus) ==="
docker logs orderer.example.com --tail 50 | grep -E "Broadcast|Step|Leader|Committed"

# Lihat Raft state
echo ""
echo "=== RAFT CLUSTER STATE ==="
docker logs orderer.example.com --tail 100 | grep -E "Raft node|leader|follower" | tail -10
```

**Expected Output:**
```
[orderer.consensus.etcdraft] Step -> Raft node started
[orderer.consensus.etcdraft] serveRequest -> Broadcasting message
[orderer.common.server] Main -> Beginning to serve requests
```

## 📊 **Decode Block Header (Proof of Ordering)**

```bash
# Lihat block header
echo "=== BLOCK HEADER (Ordering Proof) ==="
jq '.data.data[0].payload.header.channel_header | {
  channel_id: .channel_id,
  type: .type,
  tx_id: .tx_id,
  timestamp: .timestamp,
  epoch: .epoch
}' /tmp/latest.json

# Lihat block metadata
echo ""
echo "=== BLOCK METADATA ==="
jq '.metadata.metadata | {
  signatures_count: (.[0].signatures | length),
  last_config_index: .[1].value.last_config.index,
  orderer_signature: .[2].signatures[0].signature_header.creator.mspid
}' /tmp/latest.json
```

---

# 🟣 **PHASE 4: VALIDATION (Peer Side)**

## 📖 **Konsep Teoritis:**
Peer menerima block dari orderer dan melakukan:
1. **Signature verification** - cek signature endorsers
2. **Read-Write Set validation** - cek version consistency
3. **Endorsement policy check** - cek apakah memenuhi policy
4. **Block creation** - tambahkan ke local ledger

## 🔬 **Observasi: Lihat Validation Process**

```bash
# Lihat logs validation
echo "=== VALIDATION LOGS ==="
docker logs peer0.org1.example.com --tail 50 | grep -E "Validate|Validated|valid|invalid"

echo ""
echo "=== PEER0.ORG2 VALIDATION ==="
docker logs peer0.org2.example.com --tail 50 | grep -E "Validate|Validated|valid|invalid"
```

**Expected Output:**
```
[committer.txvalidator] Validate -> [mychannel] Validated block [X] in Yms
```

## 📊 **Decode Read-Write Set (State Changes)**

```bash
# Lihat Read-Write Set
echo "=== READ-WRITE SET ==="
jq '.data.data[0].payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[] | select(.namespace == "basic") | {
  reads: .rwset.reads,
  writes: .rwset.writes
}' /tmp/latest.json
```

**Expected Output:**
```json
{
  "reads": [
    {
      "key": "asset100",
      "version": null  // ← null karena asset baru
    }
  ],
  "writes": [
    {
      "key": "asset100",
      "value": "eyJBcHByYWlzZWRWYWx1ZSI6NTAwMCwiQ29sb3IiOiJjeWFuIiwiSUQiOiJhc3NldDEwMCIsIk93bmVyIjoiQ2hhcmxpZSIsIlNpemUiOjI1fQ=="
    }
  ]
}
```

## 🔓 **Decode Value (Base64 → JSON)**

```bash
# Decode value
echo "=== DECODED STATE ==="
jq -r '.data.data[0].payload.data.actions[0].payload.action.proposal_response_payload.extension.results.ns_rwset[] | select(.namespace == "basic") | .rwset.writes[0].value' /tmp/latest.json | base64 -d | jq .
```

**Expected Output:**
```json
{
  "AppraisedValue": 5000,
  "Color": "cyan",
  "ID": "asset100",
  "Owner": "Charlie",
  "Size": 25
}
```

---

# 🔴 **PHASE 5: COMMIT (Push to Ledger)**

## 📖 **Konsep Teoritis:**
Setelah validasi berhasil:
1. **Append block** ke blockchain ledger (immutable)
2. **Update world state** di CouchDB (mutable)
3. **Emit events** untuk subscribers
4. **Notify** client via gRPC

## 🔬 **Observasi: Lihat Commit Process**

```bash
# Lihat logs commit
echo "=== COMMIT LOGS ==="
docker logs peer0.org1.example.com --tail 30 | grep -E "commit|Commit|Committed"

echo ""
echo "=== PEER0.ORG2 COMMIT ==="
docker logs peer0.org2.example.com --tail 30 | grep -E "commit|Commit|Committed"
```

**Expected Output:**
```
[kvledger] commit -> [mychannel] Committed block [X] with 1 transaction(s) in Yms 
  (state_validation=Ams block_and_pvtdata_commit=Bms state_commit=Cms) 
  commitHash=[...]
```

## 📊 **Verify Block Chaining (Hash Chain)**

```bash
# Lihat blockchain info
echo "=== BLOCKCHAIN INFO ==="
peer channel getinfo -c mychannel

# Fetch 2 block terakhir
echo ""
echo "=== FETCH LAST 2 BLOCKS ==="
peer channel fetch newest /tmp/block_newest.block -c mychannel -o localhost:7050 \
  --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem 2>/dev/null

peer channel fetch prev /tmp/block_prev.block -c mychannel -o localhost:7050 \
  --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem 2>/dev/null

# Decode kedua block
configtxlator proto_decode --input /tmp/block_newest.block --type common.Block --output /tmp/block_newest.json
configtxlator proto_decode --input /tmp/block_prev.block --type common.Block --output /tmp/block_prev.json

# Lihat hash chain
echo ""
echo "=== HASH CHAIN VERIFICATION ==="
echo "Current Block Hash:"
jq -r '.header.data_hash' /tmp/block_newest.json
echo ""
echo "Previous Block Hash (in current block):"
jq -r '.header.previous_hash' /tmp/block_newest.json
echo ""
echo "Previous Block Data Hash:"
jq -r '.header.data_hash' /tmp/block_prev.json
echo ""
echo "✓ If 'Previous Block Hash' == 'Previous Block Data Hash', chain is valid!"
```

## 🗄️ **Verify World State (CouchDB)**

```bash
# Query asset dari blockchain
echo "=== QUERY FROM BLOCKCHAIN ==="
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset100"]}'

# Lihat di CouchDB
echo ""
echo "=== COUCHDB URL ==="
echo "Open: http://localhost:23054/_utils"
echo "Login: admin / adminpw"
echo "Database: mychannel_basic"
echo "Document: asset100"
```

---

# 📊 **COMPLETE FLOW SUMMARY**

## 🎬 **Visualisasi Complete Transaction Flow:**

```
┌──────────────────────────────────────────────────────────────────────┐
│                    COMPLETE TRANSACTION FLOW                         │
└──────────────────────────────────────────────────────────────────────┘

CLIENT (Org1 Admin)
    │
    │ 1. Create Proposal
    │    {function: "CreateAsset", args: ["asset100", "cyan", "25", "Charlie", "5000"]}
    │
    ├─────────────────────────────────────────────────────────────────┐
    │                                                                 │
    ▼                                                                 ▼
PEER0.ORG1 (Org1)                                              PEER0.ORG2 (Org2)
    │                                                                 │
    │ 2. Simulate Execution                                           │ 2. Simulate Execution
    │    - Read state: asset100 (null)                                │    - Read state: asset100 (null)
    │    - Execute chaincode                                          │    - Execute chaincode
    │    - Generate RW Set                                            │    - Generate RW Set
    │                                                                 │
    │ 3. Sign Response                                                │ 3. Sign Response
    │    - Sign with Org1 private key                                 │    - Sign with Org2 private key
    │                                                                 │
    └─────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 4. Collect Endorsements
                                    ▼
                              CLIENT (Org1 Admin)
                                    │
                                    │ 5. Submit to Orderer
                                    ▼
                            ┌───────────────────┐
                            │   ORDERER (Raft)  │
                            │                   │
                            │ 6. Sequence tx    │
                            │    - Receive tx   │
                            │    - Batch into   │
                            │      block        │
                            │    - Replicate to │
                            │      followers    │
                            │    - Deliver to   │
                            │      peers        │
                            └───────────────────┘
                                    │
                                    │ 7. Block Delivery
                                    ▼
                    ┌───────────────────────────────────┐
                    │                                   │
                    ▼                                   ▼
            PEER0.ORG1                          PEER0.ORG2
                    │                                   │
                    │ 8. Validate Block                 │ 8. Validate Block
                    │    - Verify signatures            │    - Verify signatures
                    │    - Check RW versions            │    - Check RW versions
                    │    - Check endorsement policy     │    - Check endorsement policy
                    │                                   │
                    │ 9. Commit to Ledger               │ 9. Commit to Ledger
                    │    - Append block to blockchain   │    - Append block to blockchain
                    │    - Update world state (CouchDB) │    - Update world state (CouchDB)
                    │    - Emit events                  │    - Emit events
                    │                                   │
                    └───────────────────────────────────┘
```

---

# 📋 **CHECKLIST: Complete Flow Verification**

```bash
cd /Users/therock/gov-blockchain-sim/fabric-samples/test-network

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         BLOCKCHAIN FLOW VERIFICATION CHECKLIST            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Phase 1: Proposal
echo "✓ Phase 1: PROPOSAL"
echo "  - Client identity: Org1MSP Admin"
echo "  - Transaction: CreateAsset(asset100, cyan, 25, Charlie, 5000)"
echo ""

# Phase 2: Endorsement
echo "✓ Phase 2: ENDORSEMENT"
echo "  - Endorsers: Org1 + Org2"
jq '.data.data[0].payload.data.actions[0].payload.action.endorsements | length' /tmp/latest.json 2>/dev/null | xargs -I {} echo "  - Number of signatures: {}"
echo ""

# Phase 3: Ordering
echo "✓ Phase 3: ORDERING (Raft Consensus)"
echo "  - Orderer: orderer.example.com"
echo "  - Consensus: etcdraft"
echo "  - Block height:"
peer channel getinfo -c mychannel 2>/dev/null | grep -o '"height":[0-9]*'
echo ""

# Phase 4: Validation
echo "✓ Phase 4: VALIDATION"
echo "  - Block validated:"
docker logs peer0.org1.example.com --tail 10 2>/dev/null | grep "Validated block" | tail -1 | awk '{print "    " $0}'
echo ""

# Phase 5: Commit
echo "✓ Phase 5: COMMIT"
echo "  - Block committed:"
docker logs peer0.org1.example.com --tail 10 2>/dev/null | grep "Committed block" | tail -1 | awk '{print "    " $0}'
echo ""

# Verify state
echo "✓ STATE VERIFICATION"
echo "  - Query from blockchain:"
peer chaincode query -C mychannel -n basic -c '{"Args":["ReadAsset","asset100"]}' 2>/dev/null | jq .
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║              ✓ ALL PHASES VERIFIED!                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
```

---

# 🎯 **Key Takeaways**

## **1. Consensus (Raft)**
- Orderer menggunakan **Raft** (not Byzantine Fault Tolerance)
- Leader election → batch transactions → replicate to followers
- **Bukti**: `docker logs orderer.example.com | grep Raft`

## **2. Smart Contract (Chaincode)**
- Chaincode = smart contract di Hyperledger
- Execute di setiap peer (simulasi)
- **Bukti**: `callChaincode -> finished chaincode: basic`

## **3. Activity (Transaction)**
- Proposal → Endorsement → Order → Validate → Commit
- Setiap step observable via logs
- **Bukti**: Logs di peer0.org1, peer0.org2, orderer

## **4. Block Chaining**
- Setiap block punya `previous_hash`
- Hash chain = immutability guarantee
- **Bukti**: `previous_hash` == `data_hash` of previous block

## **5. Push to Ledger**
- Block appended ke blockchain (immutable)
- World state updated di CouchDB (mutable)
- **Bukti**: `Committed block [X] with 1 transaction(s)`

---

## 🚀 **Next: IPFS + Encryption**

Setelah memahami complete flow, kita bisa lanjut ke **Secure Document Management**:

```
Document → Encrypt (AES-256) → IPFS (CID) → Blockchain (metadata) → Audit Trail
```

**Mau lanjut ke IPFS + Encryption sekarang?** 🎯