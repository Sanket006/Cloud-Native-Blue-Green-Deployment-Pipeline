FROM node:18-alpine

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install --production

# Copy application code
COPY . .

# Create a non-root user and group, then switch to it.
# Running as root inside a container is a security risk — if the app
# is compromised, the attacker would have full container root access.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Expose port and run
EXPOSE 3000
CMD ["npm", "start"]
