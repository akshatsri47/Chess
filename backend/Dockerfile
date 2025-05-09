# Frontend Dockerfile (place this in your React project directory)
# frontend/Dockerfile
# Backend Dockerfile (place this in your WebSocket server directory)
# backend/Dockerfile

FROM node:18
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
<<<<<<< HEAD:backend/dockerfile

=======
EXPOSE 8181
>>>>>>> bb69d0a0560ad705d3598cda5fb9ff9a8b34b4d7:backend/Dockerfile
CMD ["node", "app.js"]

