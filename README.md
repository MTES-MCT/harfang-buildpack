# Scalingo Harfang buildpack

> This buildpack aims at installing a [Harfang](https://harfang.io) agent in app on [Scalingo](https://www.scalingo.com) and let you configure it at your convenance.

## Usage

[Add this buildpack environment variable][1] to your Scalingo application to install the `Harfang` agent:

```shell
BUILDPACK_URL=https://github.com/MTES-MCT/harfang-buildpack
```

In your root directory app code, add Procfile with:
```shell
worker: hurukai_agent
```

Default version `HARFANG_VERSION` is always `latest` found in hurukai api.

## Configuration

You must set these vars in scalingo app admin console[2]:

```shell
HURUKAI_HOST=
HURUKAI_PROTOCOL=https
HURUKAI_PORT=
HURUKAI_API_URL=
HURUKAI_API_TOKEN=
HURUKAI_HLAB_TOKEN=
```

## Hacking

Environment variables are set in a `.env` file. You copy the sample one:

```shell
cp .env.sample .env
```

Run an interactive docker scalingo stack [1]:

```shell
docker run --name harfang -it -v "$(pwd)"/.env:/env/.env -v "$(pwd)":/buildpack scalingo/scalingo-22:latest bash
```

And test in it step by step in order:

```shell
bash buildpack/bin/detect
bash buildpack/bin/env.sh /env/.env /env
bash buildpack/bin/compile /build /cache /env
bash buildpack/bin/release
```

Or all in one:

```shell
docker build .
```

[1]: https://doc.scalingo.com/platform/deployment/buildpacks/custom
[2]: https://doc.scalingo.com/platform/app/environment
