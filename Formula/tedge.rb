class Tedge < Formula
    desc "IoT Device Management"
    homepage "https://thin-edge.io/"
    version "1.0.1-rc100+g63025df"
    license "Apache-2.0"

    depends_on "mosquitto" => :optional

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-dev/raw/names/tedge-macos-arm64/versions/1.0.1-rc100+g63025df/tedge.tar.gz"
            sha256 "1f0c35b226b149382698724758c77422ea88e1b51c22a54c03069eada531f11b"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-dev/raw/names/tedge-macos-amd64/versions/1.0.1-rc100+g63025df/tedge.tar.gz"
            sha256 "72e3933fd659575281602731506194c78ae2b9a439ec4c1c47ee67c5f784cc0c"
        end
    end

    def user
        Utils.safe_popen_read("id", "-un").chomp
    end

    def group
        Utils.safe_popen_read("id", "-gn").chomp
    end

    def install
        bin.install "tedge"
    end

    def post_install
        config_dir = (etc/"tedge")
        config_dir.mkpath
        config_file = config_dir/"tedge.toml"
        if !config_file.exist?
            config_file.write <<~EOS
                [sudo]
                enable = false
                
                [logs]
                path = "#{var}/log/tedge"
                
                [data]
                path = "#{var}/tedge"
                
                [http]
                bind.port=8006
                client.port=8006
            EOS
        end

        system "tedge", "init", "--config-dir", "#{config_dir}", "--user=#{user}", "--group=#{group}"
    end

    def caveats
        <<~EOS
            thin-edge.io has been installed with a default configuration file.
            You can make changes to the configuration by editing:
                #{etc}/tedge/tedge.toml
        EOS
    end

    # TODO: homebrew does not support installing multiple services
    # service do
    #     name macos: "tedge-agent",
    #         linux: "tedge-agent"
    #     run ["#{HOMEBREW_PREFIX}/bin/tedge-agent", "--config-dir", etc/"tedge"]
    #     keep_alive false
    # end
    # service do
    #     run ["#{HOMEBREW_PREFIX}/bin/tedge-mapper", "--config-dir", etc/"tedge", "c8y"]
    #     keep_alive false
    # end

    test do
        quiet_system "#{bin}/tedge", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
        quiet_system "#{bin}/tedge-agent", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
        quiet_system "#{bin}/tedge-mapper", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
    end
end
