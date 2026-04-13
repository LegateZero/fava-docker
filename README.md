# beancount-container

## Build

Fetch source repositories into the Docker build context first:

```bash
bash ./scripts/fetch-sources.sh
```

Then build the image:

```bash
docker build -t beancount-container .
```

The script writes cloned repositories to `vendor/`; that directory is intentionally ignored by git and included in the Docker build context. Git-backed Python packages are installed from `vendor/`, while `requirements.txt` contains only PyPI packages.

To build and push to Harbor, set registry credentials and run:

```bash
HARBOR_REGISTRY=harbor.example.com \
HARBOR_PROJECT=library \
HARBOR_USERNAME=user \
HARBOR_PASSWORD=password \
VERSION_TAG=latest \
ADDITIONAL_TAGS="main $(git rev-parse --short=12 HEAD)" \
PUSH_IMAGE=true \
bash ./scripts/build-and-push.sh
```

