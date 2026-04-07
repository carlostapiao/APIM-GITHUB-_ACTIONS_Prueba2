document.addEventListener('DOMContentLoaded', () => {
    const ticketForm = document.getElementById('ticketForm');
    const tableBody = document.getElementById('ticketTableBody');
    const submitBtn = document.getElementById('submitBtn');

    // Función para sanitizar texto (evita XSS básico)
    const escapeHTML = (str) => String(str).replace(/[&<>"']/g, m => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[m]);

    // Función para obtener tickets
    const fetchTickets = async () => {
        try {
            // El fetch relativo usa la <base href> automática del HTML
            const res = await fetch('api/tickets');
            
            if (!res.ok) throw new Error(`HTTP Error: ${res.status}`);
            
            const tickets = await res.json();
            tableBody.innerHTML = '';
            
            if (tickets.length === 0) {
                tableBody.innerHTML = '<tr><td colspan="5" style="text-align:center">No hay tickets abiertos.</td></tr>';
                return;
            }
            
            tickets.forEach(t => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>#${t.id}</td>
                    <td>${escapeHTML(t.usuario)}</td>
                    <td>${escapeHTML(t.asunto)}</td>
                    <td><span class="prio-${t.prioridad}">${t.prioridad}</span></td>
                    <td><span class="status-tag">${t.estado}</span></td>
                `;
                tableBody.appendChild(row);
            });
        } catch (err) {
            console.error("Fallo al cargar tickets:", err);
            tableBody.innerHTML = '<tr><td colspan="5" style="color: #ff7b72">⚠️ Error conectando con la API a través del APIM.</td></tr>';
        }
    };

    // Crear nuevo ticket
    ticketForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        
        const nuevoTicket = {
            usuario: document.getElementById('usuario').value,
            asunto: document.getElementById('asunto').value,
            prioridad: document.getElementById('prioridad').value
        };

        // Bloquear interfaz para evitar doble envío
        submitBtn.disabled = true;
        submitBtn.innerText = "Guardando en Azure SQL...";

        try {
            const res = await fetch('api/tickets', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(nuevoTicket)
            });

            if (res.ok) {
                ticketForm.reset();
                await fetchTickets(); // Recargar tabla
            } else {
                alert("Error al guardar el ticket en el servidor.");
            }
        } catch (err) {
            console.error("Error de red:", err);
            alert("No se pudo contactar con la API.");
        } finally {
            submitBtn.disabled = false;
            submitBtn.innerText = "Crear Ticket en SQL Server";
        }
    });

    // Carga inicial al abrir la página
    fetchTickets();
});