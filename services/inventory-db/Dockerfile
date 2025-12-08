FROM postgres:16-alpine

ENV POSTGRES_DB=inventory_db
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432