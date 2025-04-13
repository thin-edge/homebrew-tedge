class TedgeP11ServerMain < Formula
    desc "PKCS11 service used to enable HSM support for thin-edge.io"
    homepage "https://thin-edge.io/"
    version "$VERSION"
    license "Apache-2.0"

    depends_on "tedge" => :recommended

    on_macos do
        on_arm do
            url "$AARCH64_URL"
            sha256 "$AARCH64_SHA256"
        end
        on_intel do
            url "$X86_64_URL"
            sha256 "$X86_64_SHA256"
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
        run_dir = (var/"tedge-p11-server")
        run_dir.mkpath
    end

    def post_install
        # TODO: Change once this changes to a toml file
        config_file = (etc/"tedge/plugins/tedge-p11-server.toml")
        if !config_file.exist?
            config_file.write <<~EOS
                [device.cryptoki]
                module_path = "#{HOMEBREW_PREFIX}/lib/libykcs11.dylib"
                pin = "123456"
            EOS
        end
    end

    service do
        name macos: "tedge-p11-server-main",
             linux: "tedge-p11-server-main"
        run ["#{HOMEBREW_PREFIX}/bin/tedge-p11-server"]
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
