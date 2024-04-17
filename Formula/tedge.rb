# Code generated: DO NOT EDIT
class Tedge < Formula
    desc "IoT Device Management"
    homepage "https://thin-edge.io/"
    version "1.0.2-rc199+gcc2fb56"
    license "Apache-2.0"

    depends_on "mosquitto" => :optional

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-arm64/versions/1.0.2-rc199+gcc2fb56/tedge.tar.gz"
            sha256 "fe6ce86ff840031f764ea13126610ae2776106423afc20ff3cdd4db7258bbdb8"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-amd64/versions/1.0.2-rc199+gcc2fb56/tedge.tar.gz"
            sha256 "7e53d56cd9d5552e7f2a0e5a69f2949b9a775d7a9e8cf8e56ef6bc60307ee483"
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
                bind.port=8008
                client.port=8008
            EOS
        end

        system "tedge", "init", "--config-dir", "#{config_dir}", "--user=#{user}", "--group=#{group}"
    end

    def caveats
        <<~EOS
            thin-edge.io has been installed with a default configuration file.
            You can make changes to the configuration by editing:
                #{etc}/tedge/tedge.toml

            You need to manually edit the mosquitto configuration to add the following line:
                sh -c 'echo include_dir #{etc}/tedge/mosquitto-conf >> "#{etc}/mosquitto/mosquitto.conf"'
            
            The following components can be started manually using:

            tedge:
                #{HOMEBREW_PREFIX}/bin/tedge --config-dir "#{etc}/tedge" config set c8y.url "example.c8y.io"

            tedge-agent:
                #{HOMEBREW_PREFIX}/bin/tedge-agent --config-dir "#{etc}/tedge"
            
            tedge-mapper-c8y:
                #{HOMEBREW_PREFIX}/bin/tedge-mapper --config-dir "#{etc}/tedge" c8y

        EOS
    end

    # TODO: homebrew does not support installing multiple services
    # service do
    #     name macos: "tedge-agent",
    #          linux: "tedge-agent"
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
