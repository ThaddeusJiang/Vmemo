# Vmemo

Vmemo is a visual memory application that helps users record life in a visual way rather than with boring, easily forgotten text.

## Why Vmemo?

Our brains are naturally inclined to remember visual content better than text. Visual memory is more intuitive, impactful, and easier to review, making it a powerful tool for capturing and retaining life’s moments.

---

## Usage

## Supported Platforms

- linux/386
- linux/amd64
- linux/arm/v7
- linux/arm64/v8
- linux/ppc64le
- linux/s390x

### Pull the Image
```bash
docker pull thaddeusjiang/vmemo:latest
```

### Run the Container
```bash
docker run -d \
  -e SECRET_KEY_BASE=<your_secret_key> \
  -e DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/<db_name> \
  -e TYPESENSE_URL=http://<typesense_host>:<typesense_port> \
  -e TYPESENSE_API_KEY=<typesense_api_key> \
  -e PHX_HOST=<your_app_host> \
  -e PORT=4000 \
  -e RESEND_API_KEY=<resend_api_key> \
  -p 4000:4000 \
  thaddeusjiang/vmemo:latest
```

---

## Environment Variables

| Variable           | Description                                  |
|--------------------|----------------------------------------------|
| `SECRET_KEY_BASE`  | A secret key for verifying app integrity.    |
| `DATABASE_URL`     | Database connection URL.                    |
| `TYPESENSE_URL`    | URL for the Typesense search engine.         |
| `TYPESENSE_API_KEY`| API key for accessing Typesense.             |
| `PHX_HOST`         | Hostname for your application.               |
| `PORT`             | Port to expose the application.              |
| `RESEND_API_KEY`   | API key for the Resend email service.         |

---

For more information, visit our [documentation](https://github.com/ThaddeusJiang/vmemo).
