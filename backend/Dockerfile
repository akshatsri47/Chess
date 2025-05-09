# Frontend Dockerfile (place this in your React project directory)
# frontend/Dockerfile
# Backend Dockerfile (place this in your WebSocket server directory)
# backend/Dockerfile

FROM node:18
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
<<<<<<< HEAD:backend/Dockerfile
<<<<<<< HEAD:backend/dockerfile

=======
EXPOSE 8181
>>>>>>> bb69d0a0560ad705d3598cda5fb9ff9a8b34b4d7:backend/Dockerfile
=======
EXPOSE 8080
>>>>>>> parent of a37dc8b (just something):backend/dockerfile
CMD ["node", "app.js"]

