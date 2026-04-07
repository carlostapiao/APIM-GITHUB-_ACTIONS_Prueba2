# Usamos una imagen ligera de Node.js
FROM node:18-slim

# Crear directorio de la app
WORKDIR /usr/src/app

# Copiar archivos de dependencias primero (mejor uso de caché)
COPY package*.json ./

# Instalar dependencias
RUN npm install --only=production

# Copiar el resto del código (incluyendo la carpeta public)
COPY . .

# Exponer el puerto que configuramos en el Deployment de K8s
EXPOSE 3000

# Usuario no-root por seguridad
USER node

# Comando de arranque
CMD [ "node", "server.js" ]