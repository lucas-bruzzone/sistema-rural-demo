// Simplified Map Controller with Satellite Support
const getApiUrl = () => {
    if (window.SISTEMA_RURAL_CONFIG) {
        return `${window.SISTEMA_RURAL_CONFIG.API_BASE_URL}/properties`;
    }
    // Fallback para desenvolvimento
    return 'https://nfvbev7jgc.execute-api.us-east-1.amazonaws.com/devops/properties';
};

const PROPERTIES_API_URL = getApiUrl();

let map;
let drawnItems;
let drawControl;
let currentPolygon = null;
let properties = [];
let editingPropertyId = null;

// Helper to get correct path for localhost
function getPath(htmlFile) {
    const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    return isLocalhost ? `/src/${htmlFile}` : `/${htmlFile}`;
}

// Initialize when ready
window.addEventListener('load', function() {
    if (!auth.isAuthenticated() || !auth.isTokenValid()) {
        window.location.href = getPath('index.html');
        return;
    }
    
    setTimeout(initializeMap, 500);
});

function initializeMap() {
    try {
        // Check libraries
        if (typeof L === 'undefined' || typeof turf === 'undefined') {
            throw new Error('Bibliotecas do mapa não carregaram');
        }
        
        showStatus('Inicializando mapa...', 'info');
        
        // Create map
        map = L.map('map').setView([-21.206, -46.876], 13);

        // Define different tile layers
        const baseMaps = {
            "Mapa Padrão": L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors',
                maxZoom: 19
            }),
            
            "Satélite": L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
                attribution: '© Esri, Maxar, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, AeroGRID, IGN, and the GIS User Community',
                maxZoom: 19
            }),
            
            "Satélite com Rótulos": L.layerGroup([
                L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
                    attribution: '© Esri, Maxar, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, AeroGRID, IGN, and the GIS User Community',
                    maxZoom: 19
                }),
                L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}', {
                    maxZoom: 19
                })
            ]),
            
            "Terreno": L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}', {
                attribution: '© Esri, HERE, Garmin, Intermap, increment P Corp., GEBCO, USGS, FAO, NPS, NRCAN, GeoBase, IGN, Kadaster NL, Ordnance Survey, Esri Japan, METI, Esri China (Hong Kong), (c) OpenStreetMap contributors, and the GIS User Community',
                maxZoom: 19
            })
        };

        // Add default layer (Satellite)
        baseMaps["Satélite"].addTo(map);

        // Add layer control
        L.control.layers(baseMaps, null, {
            position: 'topright',
            collapsed: false
        }).addTo(map);

        drawnItems = new L.FeatureGroup();
        map.addLayer(drawnItems);

        setupDrawControls();
        setupMapEvents();
        setupFormEvents();
        
        loadProperties();
        
        showStatus('Mapa carregado com imagem de satélite!', 'success');
        
    } catch (error) {
        showStatus(`Erro: ${error.message}`, 'error');
    }
}

function setupDrawControls() {
    drawControl = new L.Control.Draw({
        edit: {
            featureGroup: drawnItems,
            remove: true
        },
        draw: {
            polygon: {
                allowIntersection: false,
                shapeOptions: {
                    color: '#ff4444',
                    weight: 3,
                    fillOpacity: 0.3,
                    fillColor: '#ff4444'
                }
            },
            rectangle: {
                shapeOptions: {
                    color: '#ff4444',
                    weight: 3,
                    fillOpacity: 0.3,
                    fillColor: '#ff4444'
                }
            },
            polyline: false,
            circle: false,
            marker: false,
            circlemarker: false
        }
    });
    
    map.addControl(drawControl);
}

function setupMapEvents() {
    map.on(L.Draw.Event.CREATED, function (e) {
        const layer = e.layer;
        currentPolygon = layer;
        drawnItems.addLayer(layer);
        
        const metrics = calculateMetrics(layer);
        showPropertyForm(metrics);
        showStatus('Área demarcada! Preencha os dados da propriedade.', 'info');
    });

    map.on(L.Draw.Event.EDITED, function (e) {
        e.layers.eachLayer(function (layer) {
            const metrics = calculateMetrics(layer);
            if (layer === currentPolygon) {
                updateFormMetrics(metrics);
            }
        });
        showStatus('Área editada!', 'success');
    });

    map.on(L.Draw.Event.DELETED, function (e) {
        hidePropertyForm();
        currentPolygon = null;
        showStatus('Área removida.', 'info');
    });
}

function setupFormEvents() {
    document.getElementById('savePropertyBtn').addEventListener('click', handleSave);
    document.getElementById('cancelFormBtn').addEventListener('click', hidePropertyForm);
    document.getElementById('refreshPropertiesBtn').addEventListener('click', loadProperties);
    
    // Logout handler
    const logoutBtn = document.getElementById('logoutNavBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', () => {
            auth.signOut();
            window.location.href = getPath('index.html');
        });
    }
}

function calculateMetrics(layer) {
    try {
        let coords;
        
        if (layer instanceof L.Polygon || layer instanceof L.Rectangle) {
            coords = layer.getLatLngs()[0].map(latlng => [latlng.lng, latlng.lat]);
        } else {
            return { area: '0.00', perimeter: '0', coordinates: [] };
        }
        
        if (coords[0][0] !== coords[coords.length - 1][0] || 
            coords[0][1] !== coords[coords.length - 1][1]) {
            coords.push(coords[0]);
        }
        
        const polygon = turf.polygon([coords]);
        const areaM2 = turf.area(polygon);
        const areaHectares = (areaM2 / 10000).toFixed(2);
        const perimeterKm = turf.length(polygon, {units: 'kilometers'});
        const perimeterMeters = Math.round(perimeterKm * 1000);
        
        return {
            area: areaHectares,
            perimeter: perimeterMeters,
            coordinates: coords
        };
    } catch (error) {
        return { area: '0.00', perimeter: '0', coordinates: [] };
    }
}

function showPropertyForm(metrics) {
    updateFormMetrics(metrics);
    document.getElementById('propertyForm').classList.remove('hidden');
    document.getElementById('propertyName').focus();
}

function hidePropertyForm() {
    document.getElementById('propertyForm').classList.add('hidden');
    clearForm();
    editingPropertyId = null;
    currentPolygon = null;
}

function updateFormMetrics(metrics) {
    document.getElementById('calculatedArea').textContent = metrics.area;
    document.getElementById('calculatedPerimeter').textContent = metrics.perimeter;
}

function clearForm() {
    document.getElementById('propertyName').value = '';
    document.getElementById('propertyType').value = 'fazenda';
    document.getElementById('propertyDescription').value = '';
    document.getElementById('calculatedArea').textContent = '-';
    document.getElementById('calculatedPerimeter').textContent = '-';
}

async function handleSave() {
    if (editingPropertyId) {
        await handleUpdate(editingPropertyId);
    } else {
        await handleCreate();
    }
}

async function handleCreate() {
    const name = document.getElementById('propertyName').value.trim();
    const type = document.getElementById('propertyType').value;
    const description = document.getElementById('propertyDescription').value.trim();
    
    if (!name) {
        showStatus('Digite o nome da propriedade', 'error');
        return;
    }
    
    if (!currentPolygon) {
        showStatus('Desenhe uma área no mapa primeiro', 'error');
        return;
    }
    
    const metrics = calculateMetrics(currentPolygon);
    const saveBtn = document.getElementById('savePropertyBtn');
    
    saveBtn.disabled = true;
    saveBtn.textContent = 'Salvando...';
    
    try {
        const propertyData = {
            name, type, description,
            area: parseFloat(metrics.area),
            perimeter: metrics.perimeter,
            coordinates: metrics.coordinates
        };
        
        const response = await fetch(PROPERTIES_API_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${auth.getToken()}`
            },
            body: JSON.stringify(propertyData)
        });
        
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `HTTP ${response.status}`);
        }
        
        const result = await response.json();
        
        currentPolygon.setStyle({
            color: '#00ff00',
            fillColor: '#00ff00',
            weight: 3,
            fillOpacity: 0.3
        });
        
        currentPolygon.bindPopup(`
            <strong>${result.property.name}</strong><br>
            Tipo: ${capitalizeFirst(result.property.type)}<br>
            Área: ${result.property.area} hectares<br>
            Perímetro: ${result.property.perimeter} metros
        `);
        
        currentPolygon.propertyData = result.property;
        
        hidePropertyForm();
        loadProperties();
        
        showStatus(`Propriedade "${name}" salva!`, 'success');
        
    } catch (error) {
        showStatus(`Erro ao salvar: ${error.message}`, 'error');
    } finally {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Salvar Propriedade';
    }
}

async function handleUpdate(propertyId) {
    const name = document.getElementById('propertyName').value.trim();
    const type = document.getElementById('propertyType').value;
    const description = document.getElementById('propertyDescription').value.trim();
    
    if (!name) {
        showStatus('Digite o nome da propriedade', 'error');
        return;
    }
    
    const updateData = { name, type, description };
    
    if (currentPolygon) {
        const metrics = calculateMetrics(currentPolygon);
        updateData.area = parseFloat(metrics.area);
        updateData.perimeter = metrics.perimeter;
        updateData.coordinates = metrics.coordinates;
    }
    
    const saveBtn = document.getElementById('savePropertyBtn');
    saveBtn.disabled = true;
    saveBtn.textContent = 'Atualizando...';
    
    try {
        const response = await fetch(`${PROPERTIES_API_URL}/${propertyId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${auth.getToken()}`
            },
            body: JSON.stringify(updateData)
        });
        
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.error || `HTTP ${response.status}`);
        }
        
        const result = await response.json();
        
        const index = properties.findIndex(p => p.id === propertyId);
        if (index !== -1) {
            properties[index] = result.property;
        }
        
        hidePropertyForm();
        loadProperties();
        
        showStatus(`Propriedade "${name}" atualizada!`, 'success');
        
    } catch (error) {
        showStatus(`Erro ao atualizar: ${error.message}`, 'error');
    } finally {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Salvar Propriedade';
    }
}

async function loadProperties() {
    const refreshBtn = document.getElementById('refreshPropertiesBtn');
    refreshBtn.disabled = true;
    refreshBtn.textContent = 'Carregando...';
    
    try {
        const response = await fetch(PROPERTIES_API_URL, {
            headers: { 'Authorization': `Bearer ${auth.getToken()}` }
        });
        
        if (response.ok) {
            const data = await response.json();
            properties = data.properties || [];
        } else if (response.status === 401) {
            auth.signOut();
            window.location.href = getPath('index.html');
            return;
        } else {
            properties = [];
        }
        
        updateMapProperties();
        renderPropertiesList();
        
        showStatus(`${properties.length} propriedades carregadas`, 'success');
        
    } catch (error) {
        showStatus('Erro ao carregar propriedades', 'error');
    } finally {
        refreshBtn.disabled = false;
        refreshBtn.textContent = 'Atualizar';
    }
}

function updateMapProperties() {
    drawnItems.clearLayers();
    
    properties.forEach(property => {
        if (property.coordinates && property.coordinates.length > 0) {
            const latLngs = property.coordinates.slice(0, -1).map(coord => [coord[1], coord[0]]);
            
            const polygon = L.polygon(latLngs, {
                color: '#00ff00',
                fillColor: '#00ff00',
                weight: 3,
                fillOpacity: 0.3
            });
            
            polygon.bindPopup(`
                <strong>${property.name}</strong><br>
                Tipo: ${capitalizeFirst(property.type)}<br>
                Área: ${property.area} hectares<br>
                Perímetro: ${property.perimeter} metros
            `);
            
            polygon.propertyData = property;
            drawnItems.addLayer(polygon);
        }
    });
}

function renderPropertiesList() {
    const container = document.getElementById('propertiesList');
    
    if (properties.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-icon">🗺️</div>
                <h3>Nenhuma propriedade cadastrada</h3>
                <p>Desenhe sua primeira área no mapa para começar</p>
            </div>
        `;
        return;
    }
    
    container.innerHTML = properties.map(property => `
        <div class="property-card" data-property-id="${property.id}">
            <h4>${property.name}</h4>
            <span class="property-type">${capitalizeFirst(property.type)}</span>
            <p><strong>Área:</strong> ${property.area} hectares</p>
            <p><strong>Perímetro:</strong> ${property.perimeter} metros</p>
            ${property.description ? `<p><strong>Descrição:</strong> ${property.description}</p>` : ''}
            <p class="property-date"><strong>Criado em:</strong> ${formatDate(property.createdAt)}</p>
            <div class="property-actions">
                <button class="btn btn-small btn-success" onclick="zoomToProperty('${property.id}')">
                    Ver no Mapa
                </button>
                <button class="btn btn-small" onclick="editProperty('${property.id}')">
                    Editar
                </button>
                <button class="btn btn-small btn-danger" onclick="deleteProperty('${property.id}')">
                    Excluir
                </button>
            </div>
        </div>
    `).join('');
}

function editProperty(propertyId) {
    const property = properties.find(p => p.id === propertyId);
    if (!property) return;
    
    editingPropertyId = propertyId;
    
    document.getElementById('propertyName').value = property.name;
    document.getElementById('propertyType').value = property.type;
    document.getElementById('propertyDescription').value = property.description || '';
    document.getElementById('calculatedArea').textContent = property.area;
    document.getElementById('calculatedPerimeter').textContent = property.perimeter;
    
    let targetLayer = null;
    drawnItems.eachLayer(layer => {
        if (layer.propertyData && layer.propertyData.id === propertyId) {
            targetLayer = layer;
        }
    });
    
    if (targetLayer) {
        currentPolygon = targetLayer;
        map.fitBounds(targetLayer.getBounds());
        targetLayer.openPopup();
    }
    
    document.getElementById('propertyForm').classList.remove('hidden');
    document.getElementById('savePropertyBtn').textContent = 'Atualizar Propriedade';
    document.getElementById('propertyName').focus();
    
    showStatus('Modo de edição ativado', 'info');
}

function zoomToProperty(propertyId) {
    const property = properties.find(p => p.id === propertyId);
    if (!property) return;
    
    let targetLayer = null;
    drawnItems.eachLayer(layer => {
        if (layer.propertyData && layer.propertyData.id === propertyId) {
            targetLayer = layer;
        }
    });
    
    if (targetLayer) {
        map.fitBounds(targetLayer.getBounds());
        targetLayer.openPopup();
        showStatus(`Focando na propriedade "${property.name}"`, 'info');
    }
}

async function deleteProperty(propertyId) {
    if (!confirm('Tem certeza que deseja excluir esta propriedade?')) return;
    
    try {
        const response = await fetch(`${PROPERTIES_API_URL}/${propertyId}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${auth.getToken()}` }
        });
        
        if (response.ok) {
            properties = properties.filter(p => p.id !== propertyId);
            
            drawnItems.eachLayer(layer => {
                if (layer.propertyData && layer.propertyData.id === propertyId) {
                    drawnItems.removeLayer(layer);
                }
            });
            
            renderPropertiesList();
            showStatus('Propriedade excluída', 'success');
        } else {
            throw new Error('Erro ao excluir');
        }
    } catch (error) {
        showStatus(`Erro ao excluir: ${error.message}`, 'error');
    }
}

function showStatus(message, type = 'info') {
    const statusEl = document.getElementById('mapStatus');
    if (statusEl) {
        const colors = {
            success: '🟢',
            error: '🔴',
            warning: '🟡',
            info: '🔵'
        };
        
        statusEl.textContent = `${colors[type]} ${message}`;
        statusEl.className = `status-badge ${type === 'success' ? 'online' : ''}`;
    }
    
    if (window.toast) {
        window.toast.show(message, type);
    }
}

function capitalizeFirst(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

function formatDate(dateString) {
    try {
        const date = new Date(dateString);
        return date.toLocaleDateString('pt-BR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    } catch (error) {
        return 'Data inválida';
    }
}