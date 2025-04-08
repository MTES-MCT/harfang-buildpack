# Scalingo SOC buildpack

> This buildpack aims at installing a [SOC]() agent in app on [Scalingo](https://www.scalingo.com) and let you configure it at your convenance.

## Usage

[Add this buildpack environment variable][1] to your Scalingo application to install the `SOC` app:

```shell
BUILDPACK_URL=https://github.com/MTES-MCT/soc-buildpack
```

Default version SOC is `latest` found in github releases, but you can choose another one:

```shell
scalingo env-set SOC_VERSION=1.0.0
```

## Configuration

In .env set these vars:

```shell
cp .env.sample .env
```

## Hacking

Environment variables are set in a `.env` file. You copy the sample one:

```shell
cp .env.sample .env
```

Run an interactive docker scalingo stack [2]:

```shell
docker run --name soc -it -v "$(pwd)"/.env:/env/.env -v "$(pwd)":/buildpack scalingo/scalingo-22:latest bash
```

And test in it:

```shell
bash buildpack/bin/detect
bash buildpack/bin/env.sh /env/.env /env
bash buildpack/bin/compile /build /cache /env
bash buildpack/bin/release
```

[1]: https://doc.scalingo.com/platform/deployment/buildpacks/custom
[2]: https://doc.scalingo.com/platform/deployment/buildpacks/custom
