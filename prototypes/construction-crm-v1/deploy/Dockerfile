FROM node:22.16.0-alpine
WORKDIR /app
COPY services/operations/package.json services/operations/package-lock.json ./services/operations/
RUN npm --prefix services/operations ci --omit=dev --ignore-scripts
COPY contracts ./contracts
COPY integrations/lead-crm/database ./integrations/lead-crm/database
COPY services/operations/src ./services/operations/src
COPY services/operations/public ./services/operations/public
COPY deploy/provision-operations.sql ./deploy/provision-operations.sql
USER node
CMD ["node","services/operations/src/server.mjs"]
