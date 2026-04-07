document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('form-ticket');
    const tabla = document.getElementById('tabla-tickets');

    // Función para cargar tickets
    const cargarTickets = async () => {
        try {
            // Usamos ruta relativa para que funcione con /tickets/api/tickets
            const res = await fetch('api/tickets');
            const tickets = await res.json();
            
            tabla.innerHTML = '';
            tickets.forEach(t => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>#${t.id}</td>
                    <td>${t.usuario}</td>
                    <td>${t.asunto}</td>
                    <td><span class="prio-${t.prioridad}">${t.prioridad}</span></td>
                    <td>${t.estado}</td>
                `;
                tabla.appendChild(tr);
            });
        } catch (err) {
            console.error("Error al cargar tickets:", err);
        }
    };

    // Crear nuevo ticket
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const data = {
            usuario: document.getElementById('usuario').value,
            asunto: document.getElementById('asunto').value,
            prioridad: document.getElementById('prioridad').value
        };

        await fetch('api/tickets', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });

        form.reset();
        cargarTickets();
    });

    cargarTickets();
});