# Code generated: DO NOT EDIT
class TedgeP11ServerMain < Formula
    desc "PKCS11 service used to enable HSM support for thin-edge.io"
    homepage "https://thin-edge.io/"
    version "2.0.2-rc251+g794f500"
    license "Apache-2.0"

    depends_on "tedge" => :recommended

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-p11-server-macos-arm64/versions/2.0.2-rc251+g794f500/tedge-p11-server.tar.gz"
            sha256 "59d9cf3a12f330987d209b9c6ab65b800a53b65b77999f5c5fab5a27613c84ba"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-p11-server-macos-amd64/versions/2.0.2-rc251+g794f500/tedge-p11-server.tar.gz"
            sha256 "b6af2b4c18a3ee20b3d62674445d9d9010e8a0629d4d99ec1147f47035b2a0c5"
        end
    end

    def user
        Utils.safe_popen_read("id", "-un").chomp
    end

    def group
        Utils.safe_popen_read("id", "-gn").chomp
    end

    def install
        bin.install "tedge-p11-server"
    end

    service do
        name macos: "tedge-p11-server-main",
             linux: "tedge-p11-server-main"
        run ["#{HOMEBREW_PREFIX}/bin/tedge-p11-server", "--socket-path", "#{HOMEBREW_PREFIX}/var/tedge-p11-server/tedge-p11-server.sock"]
        environment_variables TEDGE_CONFIG_DIR: etc/"tedge"
        log_path var/"log/tedge-p11-server.log"
        keep_alive true
        restart_delay 5
    end

    def caveats
        <<~EOS
            You can enable usage of the tedge-p11-socket with thin-edge.io by using tedge config

                tedge config set device.cryptoki.mode socket
                tedge config set device.cryptoki.socket_path "#{HOMEBREW_PREFIX}/var/tedge-p11-server/tedge-p11-server.sock"
                tedge config set device.cryptoki.module_path "#{HOMEBREW_PREFIX}/lib/libykcs11.dylib"

            After any changes then you will need to restart the tedge-p11-server service

                brew services restart tedge-p11-server-main
        EOS
    end

    test do
        quiet_system "#{bin}/tedge-p11-server", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
    end
end
