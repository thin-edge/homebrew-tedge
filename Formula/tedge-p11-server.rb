# Code generated: DO NOT EDIT
class TedgeP11Server < Formula
    desc "PKCS11 service used to enable HSM support for thin-edge.io"
    homepage "https://thin-edge.io/"
    version "1.6.1"
    license "Apache-2.0"

    depends_on "tedge" => :recommended

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-release/raw/names/tedge-p11-server-macos-arm64/versions/1.6.1/tedge-p11-server.tar.gz"
            sha256 "751b1363a88a522cf15863a64cacb7312a352b3639bdd9db8f974c38119552e3"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-release/raw/names/tedge-p11-server-macos-amd64/versions/1.6.1/tedge-p11-server.tar.gz"
            sha256 "5d339508cc2839a94c0d6f2ea0f2264c519e7f037e44ac44b371675187007edc"
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
        name macos: "tedge-p11-server",
             linux: "tedge-p11-server"
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

                brew services restart tedge-p11-server
        EOS
    end

    test do
        quiet_system "#{bin}/tedge-p11-server", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
    end
end
