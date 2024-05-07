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

Afterwards you should be able to use the `tedge` command.

```sh
tedge --version
```

## Testing

You can manually test the homebrew formula by checking out the project, and then running:

```sh
brew install --build-from-source Formula/tedge.rb
```
