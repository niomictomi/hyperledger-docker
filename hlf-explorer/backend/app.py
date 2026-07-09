from flask import Flask, jsonify, send_from_directory, request
from flask_cors import CORS
from blockchain import BlockchainFetcher
import os

app = Flask(__name__, static_folder='../frontend')

# Simple CORS for all routes
CORS(app, supports_credentials=True)

fetcher = BlockchainFetcher()

@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

fetcher = BlockchainFetcher()

@app.route('/')
def index():
    return send_from_directory('../frontend', 'index.html')

@app.route('/<path:path>')
def static_files(path):
    if path.startswith('api/'):
        return jsonify({'error': 'API endpoint not found'}), 404
    return send_from_directory('../frontend', path)

@app.route('/api/channel-info')
def channel_info():
    try:
        info = fetcher.get_channel_info()
        if info:
            return jsonify(info)
        return jsonify({'error': 'Failed to get channel info'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/blocks')
def get_blocks():
    try:
        blocks = fetcher.get_all_blocks()
        return jsonify(blocks)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/blocks/<int:block_num>')
def get_block(block_num):
    try:
        block = fetcher.get_block_detail(block_num)
        if block:
            return jsonify(block)
        return jsonify({'error': 'Block not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/network')
def network_info():
    try:
        info = fetcher.get_network_info()
        return jsonify(info)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/flow')
def transaction_flow():
    return jsonify({
        'phases': [
            {
                'id': 1,
                'name': 'PROPOSAL',
                'description': 'Client membuat transaction proposal',
                'actor': 'Client Application',
                'actions': [
                    'Create transaction proposal',
                    'Include chaincode function and arguments',
                    'Add client identity (MSP + certificate)',
                    'Generate proposal hash'
                ]
            },
            {
                'id': 2,
                'name': 'ENDORSEMENT',
                'description': 'Peers endorse (sign) proposal',
                'actor': 'Peer Nodes',
                'actions': [
                    'Execute chaincode (simulation)',
                    'Generate Read-Write Set',
                    'Sign proposal response',
                    'Return endorsed proposal to client'
                ]
            },
            {
                'id': 3,
                'name': 'ORDERING',
                'description': 'Orderer sequence transactions (Raft consensus)',
                'actor': 'Orderer',
                'actions': [
                    'Receive endorsed transactions',
                    'Batch transactions into blocks',
                    'Replicate blocks to followers',
                    'Deliver blocks to peers'
                ]
            },
            {
                'id': 4,
                'name': 'VALIDATION',
                'description': 'Peers validate block',
                'actor': 'Peer Nodes',
                'actions': [
                    'Verify signatures',
                    'Check Read-Write Set versions',
                    'Validate endorsement policy',
                    'Create local block'
                ]
            },
            {
                'id': 5,
                'name': 'COMMIT',
                'description': 'Push to ledger and update world state',
                'actor': 'Peer Nodes',
                'actions': [
                    'Append block to blockchain',
                    'Update world state (CouchDB)',
                    'Emit events',
                    'Notify client'
                ]
            }
        ]
    })

if __name__ == '__main__':
    print("🚀 Starting HLF Blockchain Explorer...")
    print("📍 Access at: http://localhost:7070")
    print("⚙️  CORS enabled for development")
    app.run(debug=True, port=7070, host='0.0.0.0')