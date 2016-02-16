# Custom Ngrok Builder

This script will help you to create a custom version of [Ngrok](https://github.com/inconshreveable/ngrok).

## Usage

You will need to specify the domain you will be hosting your Ngrok server, via the variable `NGROK_DOMAIN`, an example:

```
NGROK_DOMAIN="mydomain.com" ./generate.sh
```

## Output

After the execution of the script you will have two folders:
* server: Here you will find the executable for the server, always a linux executable. Also you will find a helper command `launch.sh`.
* client: Here lives the client, by default against your computer architecture. Also includes a configuration file with the correct configuration. Launch like `./ngrok -config=config.yml <port>`

## Options

By default the client will be compiled for your current architecture, but you can overwrite this using the variables: `$TUNNEL_TARGET` and `$TUNNEL_ARCH`. For creating a rpi compatible client just execute:

```
TUNNEL_TARGET="linux" TUNNEL_ARCH="arm" ./generate.sh
```
