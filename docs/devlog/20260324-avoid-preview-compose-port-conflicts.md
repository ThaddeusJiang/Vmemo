# Avoid preview compose port conflicts

## Context

The preview Docker compose stack failed to start because another local project was already binding PostgreSQL on host port `5432`. The preview stack does not require default host ports for internal service communication.

## Changes

- changed preview compose Vmemo host port from `4000` to `14000`
- changed preview compose PostgreSQL host port from `5432` to `54321`
- changed preview compose Typesense host port from `8108` to `8766`

## Result

The preview stack can run on the same machine without colliding with other local projects that already use the default PostgreSQL or Typesense ports.
