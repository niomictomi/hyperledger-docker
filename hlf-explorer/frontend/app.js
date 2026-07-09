const API_BASE = 'http://localhost:7070/api';

class BlockchainExplorer {
    constructor() {
        this.currentPage = 'dashboard';
        this.init();
    }

    init() {
        this.setupNavigation();
        this.loadPage('dashboard');
    }

    setupNavigation() {
        document.querySelectorAll('.nav-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
                e.target.classList.add('active');
                this.loadPage(e.target.dataset.page);
            });
        });
    }

    async loadPage(page) {
        this.currentPage = page;
        const content = document.getElementById('content');
        content.innerHTML = '<div class="loading">Loading</div>';

        try {
            switch(page) {
                case 'dashboard':
                    await this.loadDashboard();
                    break;
                case 'blocks':
                    await this.loadBlocks();
                    break;
                case 'flow':
                    this.loadFlow();
                    break;
                case 'network':
                    await this.loadNetwork();
                    break;
            }
        } catch (error) {
            content.innerHTML = `<div class="error">Error: ${error.message}</div>`;
        }
    }

    async loadDashboard() {
        const content = document.getElementById('content');
        
        const [channelInfo, blocks, networkInfo] = await Promise.all([
            fetch(`${API_BASE}/channel-info`).then(r => r.json()),
            fetch(`${API_BASE}/blocks`).then(r => r.json()),
            fetch(`${API_BASE}/network`).then(r => r.json())
        ]);

        content.innerHTML = `
            <div class="stats-grid">
                <div class="stat-card">
                    <h3>Block Height</h3>
                    <div class="value">${networkInfo.height}</div>
                </div>
                <div class="stat-card">
                    <h3>Channel</h3>
                    <div class="value" style="font-size: 1.5em;">${networkInfo.channel}</div>
                </div>
                <div class="stat-card">
                    <h3>Peers</h3>
                    <div class="value">${networkInfo.peers.length}</div>
                </div>
                <div class="stat-card">
                    <h3>Organizations</h3>
                    <div class="value">${networkInfo.organizations.length}</div>
                </div>
            </div>

            <div class="info-section">
                <h2>📊 Channel Information</h2>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Current Block Hash</label>
                        <div class="value">${channelInfo.currentBlockHash || 'N/A'}</div>
                    </div>
                    <div class="info-item">
                        <label>Previous Block Hash</label>
                        <div class="value">${channelInfo.previousBlockHash || 'N/A'}</div>
                    </div>
                </div>
            </div>

            <div class="info-section">
                <h2> Recent Blocks</h2>
                <div class="block-list">
                    ${blocks.slice(-5).reverse().map(block => this.createBlockCard(block)).join('')}
                </div>
            </div>
        `;

        this.attachBlockClickHandlers();
    }

    async loadBlocks() {
        const content = document.getElementById('content');
        const blocks = await fetch(`${API_BASE}/blocks`).then(r => r.json());

        content.innerHTML = `
            <h2>📦 All Blocks (${blocks.length})</h2>
            <div class="block-list">
                ${blocks.map(block => this.createBlockCard(block)).join('')}
            </div>
        `;

        this.attachBlockClickHandlers();
    }

    createBlockCard(block) {
        const typeLabels = {
            0: 'GENESIS',
            1: 'CONFIG',
            2: 'CONFIG_UPDATE',
            3: 'ENDORSER_TRANSACTION',
            4: 'ORDERER_TRANSACTION',
            5: 'DELIVER_SEEK_INFO',
            6: 'CHAINCODE_PACKAGE'
        };

        return `
            <div class="block-card" data-block="${block.block_number}">
                <h3>Block #${block.block_number}</h3>
                <div class="meta">
                    <span>🕐 ${block.timestamp ? new Date(block.timestamp * 1000).toLocaleString() : 'N/A'}</span>
                    <span>📝 ${typeLabels[block.type] || 'UNKNOWN'}</span>
                    <span>✍️ ${block.creator_mspid || 'N/A'}</span>
                    <span>📊 ${block.num_writes} writes</span>
                </div>
                ${block.writes_summary.length > 0 ? `
                    <div style="margin-top: 10px; font-size: 0.85em; color: #666;">
                        Keys: ${block.writes_summary.join(', ')}
                    </div>
                ` : ''}
            </div>
        `;
    }

    attachBlockClickHandlers() {
        document.querySelectorAll('.block-card').forEach(card => {
            card.addEventListener('click', () => {
                const blockNum = parseInt(card.dataset.block);
                this.loadBlockDetail(blockNum);
            });
        });
    }

    async loadBlockDetail(blockNum) {
        const content = document.getElementById('content');
        content.innerHTML = '<div class="loading">Loading block details</div>';

        const block = await fetch(`${API_BASE}/blocks/${blockNum}`).then(r => r.json());

        if (block.error) {
            content.innerHTML = `<div class="error">${block.error}</div>`;
            return;
        }

        const typeLabels = {
            0: 'GENESIS',
            1: 'CONFIG',
            2: 'CONFIG_UPDATE',
            3: 'ENDORSER_TRANSACTION',
            4: 'ORDERER_TRANSACTION',
            5: 'DELIVER_SEEK_INFO',
            6: 'CHAINCODE_PACKAGE'
        };

        content.innerHTML = `
            <button class="back-btn" onclick="explorer.loadPage('blocks')">← Back to Blocks</button>
            
            <div class="block-detail">
                <h2>Block #${block.block_number} Details</h2>
                
                <div class="info-section">
                    <h3>📋 Header Information</h3>
                    <div class="info-grid">
                        <div class="info-item">
                            <label>Block Number</label>
                            <div class="value">${block.block_number}</div>
                        </div>
                        <div class="info-item">
                            <label>Timestamp</label>
                            <div class="value">${block.timestamp ? new Date(block.timestamp * 1000).toLocaleString() : 'N/A'}</div>
                        </div>
                        <div class="info-item">
                            <label>Transaction ID</label>
                            <div class="value">${block.tx_id || 'N/A'}</div>
                        </div>
                        <div class="info-item">
                            <label>Channel ID</label>
                            <div class="value">${block.channel_id || 'N/A'}</div>
                        </div>
                        <div class="info-item">
                            <label>Type</label>
                            <div class="value">${typeLabels[block.type] || 'UNKNOWN'} (${block.type})</div>
                        </div>
                        <div class="info-item">
                            <label>Creator MSP ID</label>
                            <div class="value">${block.creator_mspid || 'N/A'}</div>
                        </div>
                    </div>
                </div>

                <div class="info-section">
                    <h3>📊 Transactions (${block.transactions.length})</h3>
                    <div class="transaction-list">
                        ${block.transactions.map(tx => `
                            <div class="transaction-item ${tx.type}">
                                <strong>${tx.type.toUpperCase()}</strong> - ${tx.namespace}
                                <div style="margin-top: 10px;">
                                    <strong>Key:</strong> ${tx.key}
                                </div>
                                ${tx.value ? `
                                    <div style="margin-top: 10px;">
                                        <strong>Value:</strong>
                                        <pre style="background: white; padding: 10px; border-radius: 5px; margin-top: 5px; overflow-x: auto;">${JSON.stringify(tx.value, null, 2)}</pre>
                                    </div>
                                ` : ''}
                                ${tx.version ? `
                                    <div style="margin-top: 10px; font-size: 0.9em; color: #666;">
                                        <strong>Version:</strong> Block ${tx.version.block_num}, Tx ${tx.version.tx_num}
                                    </div>
                                ` : ''}
                            </div>
                        `).join('')}
                    </div>
                </div>

                <div class="info-section">
                    <h3>️ State Writes (${block.writes.length})</h3>
                    <div class="transaction-list">
                        ${block.writes.map(write => `
                            <div class="transaction-item write">
                                <strong>${write.is_delete ? 'DELETE' : 'UPDATE'}</strong> - ${write.namespace}
                                <div style="margin-top: 10px;">
                                    <strong>Key:</strong> ${write.key}
                                </div>
                                <div style="margin-top: 10px;">
                                    <strong>Value:</strong>
                                    <pre style="background: white; padding: 10px; border-radius: 5px; margin-top: 5px; overflow-x: auto;">${JSON.stringify(write.value, null, 2)}</pre>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            </div>
        `;
    }

    async loadFlow() {
        const content = document.getElementById('content');
        const flow = await fetch(`${API_BASE}/flow`).then(r => r.json());

        content.innerHTML = `
            <h2>🔄 Transaction Flow - 5 Phases</h2>
            <div class="flow-container">
                ${flow.phases.map(phase => `
                    <div class="flow-phase" data-phase="Phase ${phase.id}">
                        <h3>${phase.name}</h3>
                        <div class="actor">Actor: ${phase.actor}</div>
                        <p>${phase.description}</p>
                        <ul>
                            ${phase.actions.map(action => `<li>${action}</li>`).join('')}
                        </ul>
                    </div>
                `).join('')}
            </div>
        `;
    }

    async loadNetwork() {
        const content = document.getElementById('content');
        const network = await fetch(`${API_BASE}/network`).then(r => r.json());

        content.innerHTML = `
            <h2>🌐 Network Topology</h2>
            <div class="network-grid">
                <div class="network-card">
                    <h3>📊 Network Info</h3>
                    <div class="info-item">
                        <label>Channel</label>
                        <div class="value">${network.channel}</div>
                    </div>
                    <div class="info-item">
                        <label>Block Height</label>
                        <div class="value">${network.height}</div>
                    </div>
                    <div class="info-item">
                        <label>Consensus</label>
                        <div class="value">${network.consensus}</div>
                    </div>
                    <div class="info-item">
                        <label>State Database</label>
                        <div class="value">${network.state_database}</div>
                    </div>
                </div>

                <div class="network-card">
                    <h3>🏢 Organizations</h3>
                    <ul class="container-list">
                        ${network.organizations.map(org => `
                            <li>
                                <span>${org}</span>
                                <span class="status-badge">Active</span>
                            </li>
                        `).join('')}
                    </ul>
                </div>

                <div class="network-card">
                    <h3>️ Peers</h3>
                    <ul class="container-list">
                        ${network.peers.map(peer => `
                            <li>
                                <span>${peer}</span>
                                <span class="status-badge">Running</span>
                            </li>
                        `).join('')}
                    </ul>
                </div>

                <div class="network-card">
                    <h3>⚙️ Orderers</h3>
                    <ul class="container-list">
                        ${network.orderers.map(orderer => `
                            <li>
                                <span>${orderer}</span>
                                <span class="status-badge">Running</span>
                            </li>
                        `).join('')}
                    </ul>
                </div>

                <div class="network-card" style="grid-column: 1 / -1;">
                    <h3>🐳 Running Containers</h3>
                    <ul class="container-list">
                        ${network.containers.map(container => `
                            <li>
                                <span>${container.name}</span>
                                <span class="status-badge">${container.status}</span>
                            </li>
                        `).join('')}
                    </ul>
                </div>
            </div>
        `;
    }
}

// Initialize app
const explorer = new BlockchainExplorer();