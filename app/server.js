const express = require('express');
const sql = require('mssql');
const path = require('path');
const app = express();

app.set('trust proxy', true);
app.use(express.json());

// --- Configuración de SQL Server ---
const config = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER, 
    database: process.env.DB_NAME,
    options: {
        encrypt: true,
        trustServerCertificate: false
    }
};

const poolPromise = new sql.ConnectionPool(config)
    .connect()
    .then(pool => {
        console.log('✅ Conexión exitosa a Azure SQL');
        return pool;
    })
    .catch(err => {
        console.error('❌ Error de conexión SQL:', err);
        process.exit(1);
    });

// --- Manejo de Rutas y Archivos Estáticos ---
// Esto permite que el CSS/JS cargue correctamente con el prefijo del APIM
app.use('/tickets', express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'public')));

// API: Obtener Tickets
app.get(['/api/tickets', '/tickets/api/tickets'], async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query("SELECT * FROM Tickets ORDER BY id DESC");
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// API: Crear Ticket
app.post(['/api/tickets', '/tickets/api/tickets'], async (req, res) => {
    try {
        const { usuario, asunto, prioridad } = req.body;
        const pool = await poolPromise;
        await pool.request()
            .input('u', sql.VarChar, usuario)
            .input('a', sql.VarChar, asunto)
            .input('p', sql.VarChar, prioridad)
            .query("INSERT INTO Tickets (usuario, asunto, prioridad, estado) VALUES (@u, @a, @p, 'Abierto')");
        res.sendStatus(201);
    } catch (err) {
        res.status(500).send(err.message);
    }
});

// Servir la interfaz visual (Página Azul)
app.get(['/', '/tickets', '/tickets/'], (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor en puerto ${PORT}`);
});