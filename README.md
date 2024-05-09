## tedge

A homebrew formula to install the thin-edge.io binaries on MacOS (x86_64 and aarch64).

The goal of installing thin-edge.io on MacOS is not to have a fully functional thin-edge.io installation, but it is more to be able to let MacOS users to run the binaries natively to assist with development and experiments without having to install a container.

The formula is automatically updated to the last thin-edge.io version in the main branch (e.g. not the official version). Upon the next thin-edge.io release (~1.1.0), the formula can be updated to use the official release (since some code changes were required to compile thin-edge.io for MacOS targets).

## Install

Install thin-edge.io using the following commands:

```sh
brew tap thin-edge/tedge
brew install tedge
```

Make sure you read the console output after installing thin-edge.io as it will help guide you how to run each of the different components (based on your context!).

Below is an example of the output when run on MacOS with Apple Silicon (M*):

```sh
thin-edge.io has been installed with a default configuration file.
You can make changes to the configuration by editing:
    /opt/homebrew/etc/tedge/tedge.toml

You need to manually edit the mosquitto configuration to add the following line:
    sh -c 'echo include_dir /opt/homebrew/etc/tedge/mosquitto-conf >> "/opt/homebrew/etc/mosquitto/mosquitto.conf"'

The following components can be started manually using:

tedge:
    /opt/homebrew/bin/tedge --config-dir "/opt/homebrew/etc/tedge" config set c8y.url "example.c8y.io"

tedge-agent:
    /opt/homebrew/bin/tedge-agent --config-dir "/opt/homebrew/etc/tedge"

tedge-mapper-c8y:
    /opt/homebrew/bin/tedge-mapper --config-dir "/opt/homebrew/etc/tedge" c8y
```

You can check the installed version by using the following command:

```sh
tedge --version
```

## Testing

You can manually test the homebrew formula by checking out the project, and then running:

```sh
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --verbose --debug --build-from-source Formula/tedge.rb
```

Or if you have already installed the package, then you need to run `reinstall`:

```sh
HOMEBREW_NO_INSTALL_FROM_API=1 brew reinstall --verbose --debug --build-from-source Formula/tedge.rb
```
