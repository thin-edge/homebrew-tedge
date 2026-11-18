# Code generated: DO NOT EDIT
class TedgeP11ServerMain < Formula
    desc "PKCS11 service used to enable HSM support for thin-edge.io"
    homepage "https://thin-edge.io/"
    version "2.1.1-rc18+g68176b7"
    license "Apache-2.0"

    depends_on "tedge" => :recommended

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-p11-server-macos-arm64/versions/2.1.1-rc18+g68176b7/tedge-p11-server.tar.gz"
            sha256 "b1301641f3ab52669e324614fb6e76275af63a6c89230f230087a2ec7a15c667"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-p11-server-macos-amd64/versions/2.1.1-rc18+g68176b7/tedge-p11-server.tar.gz"
            sha256 "1f675ddb0b8fd6f216fa3d42edb6430cb4eb28b4b31a2df8517a65187d487594"
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
        environment_variables PATH: std_service_path_env, TEDGE_CONFIG_DIR: etc/"tedge"
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
