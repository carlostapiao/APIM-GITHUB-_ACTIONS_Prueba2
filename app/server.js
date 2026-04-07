const express = require('express');
const sql = require('mssql');
const path = require('path');
const app = express();

// Configuración para confiar en el Ingress/APIM
app.set('trust proxy', true);

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const config = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER, 
    database: process.env.DB_NAME,
    options: {
        encrypt: true,
        trustServerCertificate: false // Obligatorio para Azure SQL
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

// Crear un Pool de conexiones global
const poolPromise = new sql.ConnectionPool(config)
    .connect()
    .then(pool => {
        console.log('✅ Conectado a Azure SQL Server');
        return pool;
    })
    .catch(err => {
        console.error('❌ Error de conexión a la DB:', err);
        process.exit(1);
    });

// API: Obtener Tickets
app.get('/api/tickets', async (req, res) => {
    try {
        const pool = await poolPromise;
        const result = await pool.request().query("SELECT * FROM Tickets ORDER BY id DESC");
        res.json(result.recordset);
    } catch (err) {
        res.status(500).send("Error al obtener tickets: " + err.message);
    }
});

// API: Crear Ticket
app.post('/api/tickets', async (req, res) => {
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
        res.status(500).send("Error al guardar ticket: " + err.message);
    }
});

// SPA Support: Enviar index.html para cualquier otra ruta
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
    console.log(`Arquitectura: AKS Privado + APIM`);
});