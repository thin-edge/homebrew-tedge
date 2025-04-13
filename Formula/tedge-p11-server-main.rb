# Code generated: DO NOT EDIT
class TedgeP11ServerMain < Formula
    desc "IoT Device Management"
    homepage "https://thin-edge.io/"
    version "1.4.3-rc445+g0c21166"
    license "Apache-2.0"

    # depends_on "tedge" => :recommended

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-p11-server-macos-arm64/versions/1.4.3-rc445+g0c21166/tedge-p11-server.tar.gz"
            sha256 "6dfec5e059916e0fcab0503bf2184af645be77376600ca027f028d176d8aef93"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-p11-server-macos-amd64/versions/1.4.3-rc445+g0c21166/tedge-p11-server.tar.gz"
            sha256 "8856d11e48279cd48a824b0452864a9aaab3d78db9de6851b1de9d3f76565ef9"
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
        run ["#{HOMEBREW_PREFIX}/bin/tedge-p11-server", "--socket-path", var/"tedge-p11-server/tedge-p11-server.sock", "--module-path", "#{HOMEBREW_PREFIX}/lib/libykcs11.dylib"]
        environment_variables TEDGE_CONFIG_DIR: etc/"tedge"
        log_path var/"log/tedge-p11-server.log"
        keep_alive true
        restart_delay 5
      end

    def caveats
        <<~EOS
            tedge-p11-server has been installed with a default configuration file.
            You can make changes to the configuration by editing:

                #{etc}/tedge/plugins/tedge-p11-server.toml

            Update thin-edge.io to use the tedge-p11-server unix socket:

                tedge config set device.cryptoki.mode socket
                tedge config set device.cryptoki.socket_path "#{HOMEBREW_PREFIX}/var/tedge-p11-server/tedge-p11-server.sock"
            
            Service control:

                brew services restart tedge-p11-server-main

        EOS
    end

    test do
        quiet_system "#{bin}/tedge-p11-server", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
    end
end
