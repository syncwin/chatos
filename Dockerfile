# Multi-stage build for ChatOS Frontend
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY bun.lockb ./

# Install dependencies (including devDependencies for build)
RUN npm ci

# Copy source code
COPY . .

# Accept build arguments for Vite environment variables
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ARG VITE_ANTHROPIC_API_KEY
ARG VITE_SENTRY_DSN
ARG OPENAI_API_KEY

# Set environment variables for build
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY
ENV VITE_ANTHROPIC_API_KEY=$VITE_ANTHROPIC_API_KEY
ENV VITE_SENTRY_DSN=$VITE_SENTRY_DSN
ENV OPENAI_API_KEY=$OPENAI_API_KEY
ENV NODE_ENV=production

# Build the application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

# Install serve globally and curl for health checks
RUN npm install -g serve && apk add --no-cache curl

# Check serve version for debugging
RUN serve --version

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Install only production dependencies for the final image
RUN npm ci --only=production

# Create a non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Change ownership of the app directory
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port 4173 (Vite preview default)
EXPOSE 4173

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4173 || exit 1

# Start the application
CMD ["serve", "-s", "dist", "-l", "tcp://0.0.0.0:4173"]