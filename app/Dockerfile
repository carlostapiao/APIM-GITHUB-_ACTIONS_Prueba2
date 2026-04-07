# Usar imagen oficial de Node ligera
FROM node:18-slim

# Crear directorio de trabajo
WORKDIR /usr/src/app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar dependencias
RUN npm install --production

# Copiar el resto del código (incluyendo la carpeta public/)
COPY . .

# Exponer el puerto de la aplicación
EXPOSE 3000

# Comando para iniciar
CMD [ "npm", "start" ]