# Use Node 22 LTS for native-module compatibility
FROM node:22.14.0-slim AS builder

# Install pnpm globally and native build dependencies
RUN npm install -g pnpm@9.15.1 && \
    apt-get update && \
    apt-get install -y git python3 make g++ pkg-config \
    libcairo2-dev libpango1.0-dev libjpeg62-turbo-dev libgif-dev \
    librsvg2-dev libpixman-1-dev libusb-1.0-0-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3 as the default python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Set the working directory
WORKDIR /app

# Copy package.json and other configuration files
COPY package.json ./
COPY pnpm-lock.yaml ./
COPY tsconfig.json ./

# Copy the rest of the application code
COPY ./src ./src
COPY ./characters ./characters

# Install dependencies and build the project
# Keep optional deps (Rollup needs platform packages), but skip postinstall scripts
# to avoid native module builds (e.g. node-hid/discord voice) during install.
RUN pnpm install --no-frozen-lockfile --ignore-scripts
RUN pnpm build

# Create dist directory and set permissions
RUN mkdir -p /app/dist && \
    chown -R node:node /app && \
    chmod -R 755 /app

# Switch to node user
USER node

# Create a new stage for the final image
FROM node:22.14.0-slim

# Install runtime dependencies if needed
RUN npm install -g pnpm@9.15.1
RUN apt-get update && \
    apt-get install -y git python3 \
    libcairo2 libpango-1.0-0 libjpeg62-turbo libgif7 \
    librsvg2-2 libpixman-1-0 libusb-1.0-0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built artifacts and production dependencies from the builder stage
COPY --from=builder /app/package.json /app/
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/src /app/src
COPY --from=builder /app/characters /app/characters
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/tsconfig.json /app/
COPY --from=builder /app/pnpm-lock.yaml /app/

EXPOSE 3000
# Set the command to run the application
CMD ["pnpm", "start", "--non-interactive"]
