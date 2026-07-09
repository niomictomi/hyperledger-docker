import subprocess
import json
import base64
import os
import re
from datetime import datetime

class BlockchainFetcher:
    def __init__(self):
        self.test_network_path = "/Users/therock/gov-blockchain-sim/fabric-samples/test-network"
        self.org1_msp_path = f"{self.test_network_path}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp"
        self.org1_tls_path = f"{self.test_network_path}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
        self.orderer_tls_path = f"{self.test_network_path}/organizations/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"
        
    def run_command(self, cmd, env=None):
        """Run shell command and return output"""
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30,
                env=env
            )
            return result.stdout.strip(), result.stderr.strip()
        except Exception as e:
            return "", str(e)
    
    def get_env(self):
        """Get environment variables for peer commands"""
        env = os.environ.copy()
        env.update({
            'FABRIC_CFG_PATH': f"{self.test_network_path}/compose/docker/peercfg",
            'CORE_PEER_TLS_ENABLED': 'true',
            'CORE_PEER_LOCALMSPID': 'Org1MSP',
            'CORE_PEER_ADDRESS': 'localhost:7051',
            'CORE_PEER_MSPCONFIGPATH': self.org1_msp_path,
            'CORE_PEER_TLS_ROOTCERT_FILE': self.org1_tls_path,
            'PATH': os.environ.get('PATH', '') + ':/Users/therock/gov-blockchain-sim/bin'
        })
        return env
    
    def get_channel_info(self):
        """Get blockchain channel info"""
        env = self.get_env()
        cmd = "peer channel getinfo -c mychannel"
        stdout, stderr = self.run_command(cmd, env)
        
        print(f"DEBUG get_channel_info - stdout: {stdout[:200]}")
        print(f"DEBUG get_channel_info - stderr: {stderr[:200]}")
        
        # Combine stdout and stderr
        output = stdout + "\n" + stderr
        
        # Use regex to find JSON with height
        json_pattern = r'\{"height":\d+[^}]*\}'
        match = re.search(json_pattern, output)
        
        if match:
            try:
                json_str = match.group()
                return json.loads(json_str)
            except Exception as e:
                print(f"ERROR parsing JSON: {e}")
                print(f"JSON string: {json_str}")
        
        return None
    
    def get_block_height(self):
        """Get current block height"""
        info = self.get_channel_info()
        if info and 'height' in info:
            return info['height']
        return 0
    
    def fetch_block(self, block_num):
        """Fetch and decode a specific block"""
        env = self.get_env()
        
        # Fetch block
        fetch_cmd = f"peer channel fetch {block_num} /tmp/block_{block_num}.block -c mychannel -o localhost:7050 --tls --cafile {self.orderer_tls_path}"
        stdout, stderr = self.run_command(fetch_cmd, env)
        
        print(f"DEBUG fetch_block {block_num} - stdout: {stdout[:100]}")
        print(f"DEBUG fetch_block {block_num} - stderr: {stderr[:100]}")
        
        # Check if block file exists
        if not os.path.exists(f"/tmp/block_{block_num}.block"):
            print(f"ERROR: Block file not created: /tmp/block_{block_num}.block")
            return None
        
        # Decode block
        decode_cmd = f"configtxlator proto_decode --input /tmp/block_{block_num}.block --type common.Block --output /tmp/block_{block_num}.json"
        stdout2, stderr2 = self.run_command(decode_cmd, env)
        
        print(f"DEBUG decode_block {block_num} - stdout: {stdout2[:100]}")
        print(f"DEBUG decode_block {block_num} - stderr: {stderr2[:100]}")
        
        # Check if JSON file exists
        if not os.path.exists(f"/tmp/block_{block_num}.json"):
            print(f"ERROR: JSON file not created: /tmp/block_{block_num}.json")
            return None
        
        # Read decoded block
        try:
            with open(f"/tmp/block_{block_num}.json", 'r') as f:
                block_data = json.load(f)
            return block_data
        except Exception as e:
            print(f"ERROR reading block file: {e}")
            return None
    
    def decode_base64_value(self, value):
        """Decode base64 encoded value"""
        if not value:
            return None
        try:
            decoded = base64.b64decode(value)
            return json.loads(decoded)
        except:
            return value
    
    def extract_block_info(self, block_data, block_num):
        """Extract meaningful info from block"""
        if not block_data or 'data' not in block_data:
            return None
        
        block_info = {
            'block_number': block_num,
            'timestamp': None,
            'tx_id': None,
            'channel_id': None,
            'type': None,
            'creator_mspid': None,
            'transactions': [],
            'writes': []
        }
        
        try:
            # Extract header info
            if 'data' in block_data and 'data' in block_data['data']:
                for tx_data in block_data['data']['data']:
                    if 'payload' not in tx_data:
                        continue
                    
                    payload = tx_data['payload']
                    
                    # Header info
                    if 'header' in payload and 'channel_header' in payload['header']:
                        header = payload['header']['channel_header']
                        block_info['timestamp'] = header.get('timestamp')
                        block_info['tx_id'] = header.get('tx_id')
                        block_info['channel_id'] = header.get('channel_id')
                        block_info['type'] = header.get('type')
                    
                    # Creator info
                    if 'header' in payload and 'signature_header' in payload['header']:
                        creator = payload['header']['signature_header'].get('creator', {})
                        block_info['creator_mspid'] = creator.get('mspid')
                    
                    # Transaction data
                    if 'data' in payload:
                        tx_payload = payload['data']
                        
                        # Actions (for chaincode transactions)
                        if 'actions' in tx_payload:
                            for action in tx_payload['actions']:
                                if 'payload' not in action or 'action' not in action['payload']:
                                    continue
                                
                                action_payload = action['payload']['action']
                                
                                # Endorsements
                                endorsements = action_payload.get('endorsements', [])
                                endorsers = [e['endorser']['mspid'] for e in endorsements if 'endorser' in e and 'mspid' in e['endorser']]
                                
                                # Read-Write Set
                                if 'proposal_response_payload' in action_payload:
                                    prp = action_payload['proposal_response_payload']
                                    if 'extension' in prp and 'results' in prp['extension']:
                                        results = prp['extension']['results']
                                        if 'ns_rwset' in results:
                                            for rwset in results['ns_rwset']:
                                                namespace = rwset.get('namespace', '')
                                                if 'rwset' not in rwset:
                                                    continue
                                                
                                                rw = rwset['rwset']
                                                
                                                # Reads
                                                reads = rw.get('reads', [])
                                                for read in reads:
                                                    block_info['transactions'].append({
                                                        'type': 'read',
                                                        'namespace': namespace,
                                                        'key': read.get('key'),
                                                        'version': read.get('version', {})
                                                    })
                                                
                                                # Writes
                                                writes = rw.get('writes', [])
                                                for write in writes:
                                                    decoded_value = self.decode_base64_value(write.get('value', ''))
                                                    block_info['writes'].append({
                                                        'namespace': namespace,
                                                        'key': write.get('key'),
                                                        'value': decoded_value,
                                                        'is_delete': write.get('is_delete', False)
                                                    })
                                                    
                                                    block_info['transactions'].append({
                                                        'type': 'write',
                                                        'namespace': namespace,
                                                        'key': write.get('key'),
                                                        'value': decoded_value
                                                    })
        except Exception as e:
            print(f"ERROR extracting block info: {e}")
            import traceback
            traceback.print_exc()
        
        return block_info
    
    def get_all_blocks(self):
        """Get summary of all blocks"""
        height = self.get_block_height()
        
        print(f"DEBUG get_all_blocks - height: {height}")
        
        if height == 0:
            print("WARNING: Block height is 0")
            return []
        
        blocks = []
        
        for i in range(height):
            print(f"DEBUG - Fetching block {i}/{height-1}...")
            block_data = self.fetch_block(i)
            if block_data:
                block_info = self.extract_block_info(block_data, i)
                if block_info:
                    blocks.append({
                        'block_number': i,
                        'timestamp': block_info['timestamp'],
                        'tx_id': block_info['tx_id'],
                        'channel_id': block_info['channel_id'],
                        'type': block_info['type'],
                        'creator_mspid': block_info['creator_mspid'],
                        'num_writes': len(block_info['writes']),
                        'writes_summary': [w['key'] for w in block_info['writes'][:3]]
                    })
            else:
                print(f"WARNING: Failed to fetch block {i}")
        
        return blocks
    
    def get_block_detail(self, block_num):
        """Get detailed info for a specific block"""
        block_data = self.fetch_block(block_num)
        if block_data:
            return self.extract_block_info(block_data, block_num)
        return None
    
    def get_network_info(self):
        """Get network topology info"""
        env = self.get_env()
        
        # Get peer info
        cmd = "docker ps --format '{{.Names}} {{.Status}}' | grep -E 'peer|orderer|couchdb'"
        stdout, _ = self.run_command(cmd)
        
        containers = []
        for line in stdout.split('\n'):
            if line.strip():
                parts = line.split(' ', 1)
                containers.append({
                    'name': parts[0],
                    'status': parts[1] if len(parts) > 1 else ''
                })
        
        return {
            'channel': 'mychannel',
            'height': self.get_block_height(),
            'peers': ['peer0.org1.example.com', 'peer0.org2.example.com'],
            'orderers': ['orderer.example.com'],
            'organizations': ['Org1MSP', 'Org2MSP'],
            'containers': containers,
            'consensus': 'Raft (etcdraft)',
            'state_database': 'CouchDB'
        }