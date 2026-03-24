# Align preview compose with existing postgres volume

## Context

The preview stack reused an existing PostgreSQL data directory. That data directory was already initialized with the default `postgres` role and the `vmemo_dev` database, so the newer `vmemo` role configuration could not authenticate.

## Changes

- changed preview compose `DATABASE_URL` to use `postgres:postgres@postgres/vmemo_dev`
- changed preview compose PostgreSQL bootstrap variables to `POSTGRES_USER=postgres`
- changed preview compose PostgreSQL bootstrap variables to `POSTGRES_PASSWORD=postgres`
- changed preview compose PostgreSQL bootstrap database to `vmemo_dev`

## Result

The preview stack now matches the existing local PostgreSQL volume and can start without reinitializing the database.
