// Enhanced Dashboard Controller with Server-side PDF Report Generation
class Dashboard {
    constructor() {
        this.properties = [];
        this.selectedProperties = new Set();
        this.apiBaseUrl = this.getApiUrl();
        this.websocketUrl = this.getWebSocketUrl();
        this.ws = null;
        this.wsReconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.csvData = null;
        this.init();
    }

    getApiUrl() {
        if (window.SISTEMA_RURAL_CONFIG) {
            return window.SISTEMA_RURAL_CONFIG.API_BASE_URL;
        }
    }

    getWebSocketUrl() {
        if (window.SISTEMA_RURAL_CONFIG) {
            return window.SISTEMA_RURAL_CONFIG.WEBSOCKET_URL;
        }
    }

    init() {
        if (!auth.isAuthenticated() || !auth.isTokenValid()) {
            window.location.href = '/';
            return;
        }
        
        this.updateUserAvatar();
        this.loadDashboardData();
        this.updateLastAccess();
        this.bindEvents();
        this.initWebSocket();
    }

    bindEvents() {
        // Selection controls
        const selectAllBtn = document.getElementById('selectAllBtn');
        const clearSelectionBtn = document.getElementById('clearSelectionBtn');
        const generateReportBtn = document.getElementById('generateReportBtn');
        
        if (selectAllBtn) selectAllBtn.addEventListener('click', () => this.selectAll());
        if (clearSelectionBtn) clearSelectionBtn.addEventListener('click', () => this.clearSelection());
        if (generateReportBtn) generateReportBtn.addEventListener('click', () => this.generateReport());
        
        // CSV Import
        const importCsvBtn = document.getElementById('importCsvBtn');
        const csvFileInput = document.getElementById('csvFileInput');
        const confirmImportBtn = document.getElementById('confirmImportBtn');
        const cancelImportBtn = document.getElementById('cancelImportBtn');
        const csvModalClose = document.getElementById('csvModalClose');
        
        if (importCsvBtn) importCsvBtn.addEventListener('click', () => this.openCsvModal());
        if (csvFileInput) csvFileInput.addEventListener('change', (e) => this.handleCsvFile(e));
        if (confirmImportBtn) confirmImportBtn.addEventListener('click', () => this.importCsvData());
        if (cancelImportBtn) cancelImportBtn.addEventListener('click', () => this.resetCsvModal());
        if (csvModalClose) csvModalClose.addEventListener('click', () => this.closeCsvModal());
    }

    updateUserAvatar() {
        if (window.userMenu) {
            const userInfo = auth.getUserInfo();
            if (userInfo) {
                window.userMenu.updateUser(userInfo);
            }
        } else {
            setTimeout(() => this.updateUserAvatar(), 200);
        }
    }

    async loadDashboardData() {
        try {
            await this.loadProperties();
            this.updateStats();
            this.renderPropertiesList();
        } catch (error) {
            console.error('Error loading dashboard data:', error);
            this.showDemoData();
        }
    }

    async loadProperties() {
        const token = auth.getToken();
        if (!token) throw new Error('No auth token');

        try {
            const response = await fetch(`${this.apiBaseUrl}/properties`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });

            if (response.ok) {
                const data = await response.json();
                this.properties = data.properties || [];
            } else {
                this.properties = [];
            }
        } catch (error) {
            console.error('Error loading properties:', error);
            this.showDemoData();
        }
    }

    showDemoData() {
        // Fallback demo data if API fails
        this.properties = [];
        this.updateStats();
        this.renderPropertiesList();
    }

    updateStats() {
        const totalProperties = this.properties.length;
        const totalArea = this.properties.reduce((sum, p) => sum + (p.area || 0), 0);
        const totalPerimeter = this.properties.reduce((sum, p) => sum + (p.perimeter || 0), 0);
        const selectedCount = this.selectedProperties.size;

        const totalPropertiesEl = document.getElementById('totalProperties');
        const totalAreaEl = document.getElementById('totalArea');
        const totalPerimeterEl = document.getElementById('totalPerimeter');

        if (totalPropertiesEl) totalPropertiesEl.textContent = totalProperties;
        if (totalAreaEl) totalAreaEl.textContent = totalArea.toFixed(1);
        if (totalPerimeterEl) totalPerimeterEl.textContent = (totalPerimeter / 1000).toFixed(1);

        // Enable/disable report button
        const reportBtn = document.getElementById('generateReportBtn');
        if (reportBtn) {
            reportBtn.disabled = selectedCount === 0;
            reportBtn.textContent = selectedCount > 0 ? 
                `📄 Gerar Relatório (${selectedCount})` : '📄 Gerar Relatório';
        }
    }

    renderPropertiesList() {
        const container = document.getElementById('propertiesList');
        if (!container) return;
        
        if (this.properties.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-icon">🗺️</div>
                    <h3>Nenhuma propriedade cadastrada</h3>
                    <p>Comece criando sua primeira propriedade no mapeamento</p>
                    <a href="mapeamento.html" class="btn btn-primary">Criar Propriedade</a>
                </div>
            `;
            return;
        }

        container.innerHTML = this.properties.map(prop => `
            <div class="property-item" data-property-id="${prop.id}">
                <div class="property-selection">
                    <label class="checkbox-container">
                        <input type="checkbox" 
                               class="property-checkbox" 
                               data-property-id="${prop.id}"
                               ${this.selectedProperties.has(prop.id) ? 'checked' : ''}>
                        <span class="checkmark"></span>
                    </label>
                </div>
                <div class="property-content">
                    <div class="property-header">
                        <h4>${prop.name}</h4>
                        <span class="property-type">${this.capitalizeFirst(prop.type)}</span>
                        ${this.getAnalysisStatusBadge(prop.analysisStatus)}
                    </div>
                    <div class="property-metrics">
                        <span>📐 ${prop.area} ha</span>
                        <span>📏 ${(prop.perimeter / 1000).toFixed(1)} km</span>
                    </div>
                    <div class="property-date">
                        Criado em ${new Date(prop.createdAt).toLocaleDateString('pt-BR')}
                    </div>
                    ${prop.analysisStatus === 'completed' ? `
                        <div class="analysis-preview">
                            <button class="btn btn-small btn-outline" onclick="window.dashboard.viewAnalysis('${prop.id}')">
                                📊 Ver Análise
                            </button>
                        </div>
                    ` : ''}
                </div>
                <div class="property-actions">
                    <button class="btn btn-small btn-outline" onclick="window.open('mapeamento.html', '_blank')">
                        🗺️ Ver no Mapa
                    </button>
                </div>
            </div>
        `).join('');

        // Bind checkbox events
        container.querySelectorAll('.property-checkbox').forEach(checkbox => {
            checkbox.addEventListener('change', (e) => {
                this.togglePropertySelection(e.target.dataset.propertyId, e.target.checked);
            });
        });
    }

    getAnalysisStatusBadge(status) {
        const badges = {
            'pending': '<span class="analysis-badge pending">⏳ Análise pendente</span>',
            'processing': '<span class="analysis-badge processing">🔄 Processando</span>',
            'completed': '<span class="analysis-badge completed">✅ Análise concluída</span>',
            'error': '<span class="analysis-badge error">❌ Erro na análise</span>'
        };
        return badges[status] || '';
    }

    async viewAnalysis(propertyId) {
        try {
            const response = await fetch(`${this.apiBaseUrl}/properties/${propertyId}/analysis`, {
                headers: { 'Authorization': `Bearer ${auth.getToken()}` }
            });

            if (response.ok) {
                const analysisData = await response.json();
                this.showAnalysisModal(analysisData);
            } else {
                if (window.toast) {
                    window.toast.show('Erro ao carregar análise', 'error');
                }
            }
        } catch (error) {
            console.error('Erro ao buscar análise:', error);
            if (window.toast) {
                window.toast.show('Erro ao buscar análise', 'error');
            }
        }
    }

    showAnalysisModal(analysisData) {
        const property = this.properties.find(p => p.id === analysisData.propertyId);
        if (!property) return;

        const analysis = analysisData.analysis;
        
        // Create modal content
        const modalContent = `
            <div class="analysis-modal-content">
                <h3>Análise Geoespacial - ${property.name}</h3>
                
                ${analysis.analysisResults ? `
                    <div class="analysis-results">
                        ${analysis.analysisResults.elevation ? `
                            <div class="analysis-section">
                                <h4>🏔️ Elevação</h4>
                                <div class="analysis-metrics">
                                    <span>Média: ${analysis.analysisResults.elevation.avg_elevation}m</span>
                                    <span>Máxima: ${analysis.analysisResults.elevation.max_elevation}m</span>
                                    <span>Mínima: ${analysis.analysisResults.elevation.min_elevation}m</span>
                                </div>
                            </div>
                        ` : ''}
                        
                        ${analysis.analysisResults.ndvi ? `
                            <div class="analysis-section">
                                <h4>🌱 Vegetação (NDVI)</h4>
                                <div class="analysis-metrics">
                                    <span>NDVI médio: ${analysis.analysisResults.ndvi.avg_ndvi}</span>
                                    <span>Cobertura: ${analysis.analysisResults.ndvi.vegetation_coverage}%</span>
                                    <span>Classificação: ${analysis.analysisResults.ndvi.classification}</span>
                                </div>
                            </div>
                        ` : ''}
                        
                        ${analysis.analysisResults.slope ? `
                            <div class="analysis-section">
                                <h4>📐 Declividade</h4>
                                <div class="analysis-metrics">
                                    <span>Inclinação média: ${analysis.analysisResults.slope.avg_slope}°</span>
                                    <span>Máxima: ${analysis.analysisResults.slope.max_slope}°</span>
                                    <span>Classificação: ${analysis.analysisResults.slope.slope_classification}</span>
                                </div>
                            </div>
                        ` : ''}
                        
                        ${analysis.analysisResults.weather ? `
                            <div class="analysis-section">
                                <h4>🌤️ Clima</h4>
                                <div class="analysis-metrics">
                                    <span>Chuva anual: ${analysis.analysisResults.weather.annual_rainfall}mm</span>
                                    <span>Temperatura: ${analysis.analysisResults.weather.avg_temperature}°C</span>
                                    <span>Zona climática: ${analysis.analysisResults.weather.climate_zone}</span>
                                </div>
                            </div>
                        ` : ''}
                        
                        <div class="analysis-footer">
                            <small>Análise concluída em: ${new Date(analysis.completedAt).toLocaleDateString('pt-BR')}</small>
                        </div>
                    </div>
                ` : '<p>Dados de análise não disponíveis</p>'}
            </div>
        `;

        // Show modal (reuse existing modal)
        const modal = document.getElementById('loginModal');
        if (modal) {
            const modalTitle = modal.querySelector('#modalTitle');
            const modalBody = modal.querySelector('.modal-body');
            
            if (modalTitle) modalTitle.textContent = 'Análise Geoespacial';
            if (modalBody) modalBody.innerHTML = modalContent;
            
            modal.classList.remove('hidden');
        }
    }

    togglePropertySelection(propertyId, selected) {
        if (selected) {
            this.selectedProperties.add(propertyId);
        } else {
            this.selectedProperties.delete(propertyId);
        }
        
        this.updateStats();
    }

    selectAll() {
        this.properties.forEach(prop => {
            this.selectedProperties.add(prop.id);
        });
        
        // Update checkboxes
        document.querySelectorAll('.property-checkbox').forEach(checkbox => {
            checkbox.checked = true;
        });
        
        this.updateStats();
    }

    clearSelection() {
        this.selectedProperties.clear();
        
        // Update checkboxes
        document.querySelectorAll('.property-checkbox').forEach(checkbox => {
            checkbox.checked = false;
        });
        
        this.updateStats();
    }

    async generateReport() {
        const selectedProps = this.properties.filter(p => this.selectedProperties.has(p.id));
        
        if (selectedProps.length === 0) {
            if (window.toast) {
                window.toast.show('Selecione pelo menos uma propriedade', 'warning');
            }
            return;
        }

        const reportBtn = document.getElementById('generateReportBtn');
        if (reportBtn) {
            reportBtn.disabled = true;
            reportBtn.textContent = '⏳ Gerando relatório...';
        }

        try {
            const propertyIds = selectedProps.map(p => p.id);
            
            const response = await fetch(`${this.apiBaseUrl}/properties/report`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${auth.getToken()}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    propertyIds: propertyIds
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            const result = await response.json();
            
            this.downloadPDF(result.pdf, result.filename);
            
            if (window.toast) {
                window.toast.show(`Relatório PDF gerado: ${result.filename}`, 'success');
            }
            
        } catch (error) {
            console.error('Erro ao gerar relatório:', error);
            if (window.toast) {
                window.toast.show(`Erro ao gerar relatório: ${error.message}`, 'error');
            }
        } finally {
            if (reportBtn) {
                reportBtn.disabled = false;
                const selectedCount = this.selectedProperties.size;
                reportBtn.textContent = selectedCount > 0 ? 
                    `📄 Gerar Relatório (${selectedCount})` : '📄 Gerar Relatório';
            }
        }
    }

    // Função auxiliar para download do PDF
    downloadPDF(pdfBase64, filename) {
        try {
            // Converter base64 para blob
            const byteCharacters = atob(pdfBase64);
            const byteNumbers = new Array(byteCharacters.length);
            
            for (let i = 0; i < byteCharacters.length; i++) {
                byteNumbers[i] = byteCharacters.charCodeAt(i);
            }
            
            const byteArray = new Uint8Array(byteNumbers);
            const blob = new Blob([byteArray], { type: 'application/pdf' });
            
            // Criar link de download
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = filename;
            
            // Trigger download
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            
            // Limpar URL object
            window.URL.revokeObjectURL(url);
            
        } catch (error) {
            console.error('Erro ao fazer download do PDF:', error);
            if (window.toast) {
                window.toast.show('Erro ao fazer download do arquivo', 'error');
            }
        }
    }

    updateLastAccess() {
        const now = new Date();
        const formatted = now.toLocaleDateString('pt-BR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
        
        const lastAccessEl = document.getElementById('lastAccess');
        if (lastAccessEl) {
            lastAccessEl.textContent = formatted;
        }
    }

    capitalizeFirst(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    // ========== CSV IMPORT FUNCTIONALITY ==========
    
    openCsvModal() {
        const csvModal = document.getElementById('csvImportModal');
        if (csvModal) {
            csvModal.classList.remove('hidden');
            this.resetCsvModal();
        }
    }

    closeCsvModal() {
        const csvModal = document.getElementById('csvImportModal');
        if (csvModal) {
            csvModal.classList.add('hidden');
            this.resetCsvModal();
        }
    }

    resetCsvModal() {
        const uploadSection = document.getElementById('csvUploadSection');
        const previewSection = document.getElementById('csvPreviewSection');
        const statusSection = document.getElementById('csvImportStatus');
        const fileInput = document.getElementById('csvFileInput');

        if (uploadSection) uploadSection.classList.remove('hidden');
        if (previewSection) previewSection.classList.add('hidden');
        if (statusSection) statusSection.classList.add('hidden');
        if (fileInput) fileInput.value = '';
        
        this.csvData = null;
    }

    handleCsvFile(event) {
        const file = event.target.files[0];
        if (!file) return;

        // Validate file
        if (!file.name.toLowerCase().endsWith('.csv')) {
            if (window.toast) {
                window.toast.show('Por favor, selecione um arquivo CSV válido', 'error');
            }
            return;
        }

        if (file.size > 5 * 1024 * 1024) { // 5MB
            if (window.toast) {
                window.toast.show('Arquivo muito grande. Máximo 5MB', 'error');
            }
            return;
        }

        // Read and parse CSV
        const reader = new FileReader();
        reader.onload = (e) => this.parseCsvContent(e.target.result);
        reader.readAsText(file);
    }

    parseCsvContent(csvContent) {
        try {
            const lines = csvContent.trim().split('\n');
            if (lines.length < 2) {
                throw new Error('CSV deve ter pelo menos um cabeçalho e uma linha de dados');
            }

            // Parse header
            const header = lines[0].split(',').map(h => h.trim().toLowerCase());
            
            // Validate required columns
            const requiredColumns = ['nome', 'tipo', 'area', 'perimetro', 'coordenadas'];
            const missingColumns = requiredColumns.filter(col => !header.includes(col));
            
            if (missingColumns.length > 0) {
                throw new Error(`Colunas obrigatórias ausentes: ${missingColumns.join(', ')}`);
            }

            // Parse data rows
            const data = [];
            const errors = [];

            for (let i = 1; i < lines.length; i++) {
                const line = lines[i].trim();
                if (!line) continue;

                try {
                    const values = this.parseCsvLine(line);
                    if (values.length !== header.length) {
                        errors.push(`Linha ${i + 1}: Número incorreto de colunas`);
                        continue;
                    }

                    const rowData = {};
                    header.forEach((col, index) => {
                        rowData[col] = values[index];
                    });

                    // Validate and convert data
                    const property = this.validateCsvRow(rowData, i + 1);
                    if (property.valid) {
                        data.push(property.data);
                    } else {
                        errors.push(`Linha ${i + 1}: ${property.error}`);
                    }
                } catch (e) {
                    errors.push(`Linha ${i + 1}: ${e.message}`);
                }
            }

            if (data.length === 0) {
                throw new Error('Nenhum dado válido encontrado no CSV');
            }

            // Show preview
            this.csvData = data;
            this.showCsvPreview(data, errors);

        } catch (error) {
            if (window.toast) {
                window.toast.show(`Erro ao processar CSV: ${error.message}`, 'error');
            }
        }
    }

    parseCsvLine(line) {
        const values = [];
        let current = '';
        let inQuotes = false;
        
        for (let i = 0; i < line.length; i++) {
            const char = line[i];
            
            if (char === '"') {
                inQuotes = !inQuotes;
            } else if (char === ',' && !inQuotes) {
                values.push(current.trim());
                current = '';
            } else {
                current += char;
            }
        }
        
        values.push(current.trim());
        return values;
    }

    validateCsvRow(row, lineNumber) {
        try {
            // Required fields
            const nome = row.nome?.trim();
            if (!nome || nome.length < 2) {
                return { valid: false, error: 'Nome inválido' };
            }

            const tipo = row.tipo?.trim().toLowerCase() || 'fazenda';
            const validTypes = ['fazenda', 'sitio', 'chacara', 'terreno', 'outros'];
            if (!validTypes.includes(tipo)) {
                return { valid: false, error: `Tipo inválido: ${tipo}` };
            }

            const area = parseFloat(row.area);
            if (isNaN(area) || area <= 0) {
                return { valid: false, error: 'Área inválida' };
            }

            const perimetro = parseFloat(row.perimetro);
            if (isNaN(perimetro) || perimetro <= 0) {
                return { valid: false, error: 'Perímetro inválido' };
            }

            // Parse coordinates
            let coordinates;
            try {
                coordinates = JSON.parse(row.coordenadas);
                if (!Array.isArray(coordinates) || coordinates.length < 4) {
                    throw new Error('Coordenadas insuficientes');
                }
            } catch (e) {
                return { valid: false, error: 'Coordenadas em formato inválido (deve ser JSON)' };
            }

            return {
                valid: true,
                data: {
                    name: nome,
                    type: tipo,
                    description: row.descricao?.trim() || '',
                    area: area,
                    perimeter: perimetro,
                    coordinates: coordinates
                }
            };

        } catch (error) {
            return { valid: false, error: error.message };
        }
    }

    showCsvPreview(data, errors) {
        const uploadSection = document.getElementById('csvUploadSection');
        const previewSection = document.getElementById('csvPreviewSection');

        if (uploadSection) uploadSection.classList.add('hidden');
        if (previewSection) previewSection.classList.remove('hidden');

        // Create preview table
        const preview = data.slice(0, 5);
        let tableHtml = `
            <table class="csv-preview-table">
                <thead>
                    <tr>
                        <th>Nome</th>
                        <th>Tipo</th>
                        <th>Área (ha)</th>
                        <th>Perímetro (m)</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
        `;

        preview.forEach(prop => {
            tableHtml += `
                <tr>
                    <td>${prop.name}</td>
                    <td>${this.capitalizeFirst(prop.type)}</td>
                    <td>${prop.area.toFixed(2)}</td>
                    <td>${prop.perimeter.toFixed(0)}</td>
                    <td><span class="status-valid">✅ Válido</span></td>
                </tr>
            `;
        });

        tableHtml += '</tbody></table>';
        
        const previewTable = document.getElementById('csvPreviewTable');
        if (previewTable) {
            previewTable.innerHTML = tableHtml;
        }

        // Show stats
        const statsHtml = `
            <div class="csv-stats-grid">
                <div class="stat-item">
                    <span class="stat-label">Total de propriedades:</span>
                    <span class="stat-value">${data.length}</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">Erros encontrados:</span>
                    <span class="stat-value ${errors.length > 0 ? 'error' : ''}">${errors.length}</span>
                </div>
                ${data.length > 5 ? `
                <div class="stat-item">
                    <span class="stat-label">Mostrando:</span>
                    <span class="stat-value">5 de ${data.length}</span>
                </div>` : ''}
            </div>
        `;

        const csvStats = document.getElementById('csvStats');
        if (csvStats) {
            csvStats.innerHTML = statsHtml;
        }

        // Show errors if any
        if (errors.length > 0) {
            const errorHtml = `
                <div class="csv-errors">
                    <h5>⚠️ Linhas com erro (serão ignoradas):</h5>
                    <ul>${errors.slice(0, 10).map(err => `<li>${err}</li>`).join('')}</ul>
                    ${errors.length > 10 ? `<p><small>...e mais ${errors.length - 10} erros</small></p>` : ''}
                </div>
            `;
            if (csvStats) {
                csvStats.innerHTML += errorHtml;
            }
        }
    }

    async importCsvData() {
        if (!this.csvData || this.csvData.length === 0) {
            if (window.toast) {
                window.toast.show('Nenhum dado válido para importar', 'error');
            }
            return;
        }

        const previewSection = document.getElementById('csvPreviewSection');
        const statusSection = document.getElementById('csvImportStatus');
        const statusText = document.getElementById('importStatusText');
        const confirmBtn = document.getElementById('confirmImportBtn');
        
        if (previewSection) previewSection.classList.add('hidden');
        if (statusSection) statusSection.classList.remove('hidden');
        if (confirmBtn) confirmBtn.disabled = true;

        try {
            if (statusText) {
                statusText.textContent = `Importando ${this.csvData.length} propriedades...`;
            }

            const response = await fetch(`${this.apiBaseUrl}/properties/import`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${auth.getToken()}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    properties: this.csvData
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || `HTTP ${response.status}`);
            }

            const result = await response.json();
            
            if (statusText) {
                statusText.textContent = '✅ Importação concluída com sucesso!';
            }
            
            if (window.toast) {
                window.toast.show(`${result.imported} propriedades importadas com sucesso!`, 'success');
            }

            setTimeout(() => {
                this.loadDashboardData();
                this.closeCsvModal();
            }, 2000);

        } catch (error) {
            console.error('Erro na importação:', error);
            if (statusText) {
                statusText.textContent = '❌ Erro na importação';
            }
            
            if (window.toast) {
                window.toast.show(`Erro na importação: ${error.message}`, 'error');
            }

            setTimeout(() => {
                if (statusSection) statusSection.classList.add('hidden');
                if (previewSection) previewSection.classList.remove('hidden');
            }, 3000);
        } finally {
            if (confirmBtn) confirmBtn.disabled = false;
        }
    }
    
    // ========== WEBSOCKET FUNCTIONALITY ==========
    
    async initWebSocket() {
        const token = auth.getToken();
        if (!token) return;
        
        try {
            this.ws = new WebSocket(`${this.websocketUrl}?token=${token}`);
            
            this.ws.onopen = () => {
                console.log('WebSocket conectado');
                this.wsReconnectAttempts = 0;
                
                // Subscribe to analysis notifications
                this.sendWebSocketMessage({
                    action: 'subscribe',
                    topic: 'analysis.completed'
                });
            };
            
            this.ws.onmessage = (event) => {
                try {
                    // Check if message data is valid JSON
                    if (!event.data || event.data.trim() === '') {
                        console.warn('WebSocket: Received empty message');
                        return;
                    }
                    
                    const message = JSON.parse(event.data);
                    this.handleWebSocketMessage(message);
                } catch (error) {
                    console.error('WebSocket: Error parsing message:', error, 'Raw data:', event.data);
                }
            };
            
            this.ws.onclose = (event) => {
                console.log('WebSocket desconectado:', event.code, event.reason);
                this.scheduleReconnect();
            };
            
            this.ws.onerror = (error) => {
                console.error('WebSocket error:', error);
            };
            
        } catch (error) {
            console.error('Error initializing WebSocket:', error);
        }
    }

    sendWebSocketMessage(message) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            try {
                this.ws.send(JSON.stringify(message));
            } catch (error) {
                console.error('Error sending WebSocket message:', error);
            }
        }
    }

    handleWebSocketMessage(message) {
        console.log('WebSocket message received:', message);
        
        if (message.type === 'analysis_notification' && message.event === 'completed') {
            const propertyIndex = this.properties.findIndex(p => p.id === message.propertyId);
            if (propertyIndex !== -1) {
                this.properties[propertyIndex].analysisStatus = 'completed';
                this.renderPropertiesList();
            }
            
            if (window.toast) {
                window.toast.show(message.message || 'Análise concluída!', 'success');
            }
        }
    }

    scheduleReconnect() {
        if (this.wsReconnectAttempts < this.maxReconnectAttempts) {
            this.wsReconnectAttempts++;
            const delay = Math.min(1000 * Math.pow(2, this.wsReconnectAttempts), 30000);
            
            console.log(`WebSocket: Tentativa de reconexão ${this.wsReconnectAttempts} em ${delay}ms`);
            
            setTimeout(() => {
                this.initWebSocket();
            }, delay);
        } else {
            console.log('WebSocket: Máximo de tentativas de reconexão atingido');
        }
    }

    closeWebSocket() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }
}

// Export for global use
window.Dashboard = Dashboard;