# Code generated: DO NOT EDIT
class Tedge < Formula
    desc "IoT Device Management"
    homepage "https://thin-edge.io/"
    version "1.0.2-rc315+g1828e73"
    license "Apache-2.0"

    depends_on "mosquitto" => :optional

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-arm64/versions/1.0.2-rc315+g1828e73/tedge.tar.gz"
            sha256 "d9367a65b87d6b140cd6d9713be7df2f2a0a04fc3acad66f959815e231124c72"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-amd64/versions/1.0.2-rc315+g1828e73/tedge.tar.gz"
            sha256 "4d26a32e3ba32c9c7e21d2e4ece0cdfb8c43d6e0519346d9b072b827327641ad"
        end
    end

    resource "sm-plugin-brew" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/sm-plugins/brew"
        sha256 "f29f7cffb93be0adb8b8376bc74e249c70703799ea048a653a2f29af33dc5204"
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

        # Install sm-plugins in a shared folder
        share_sm_plugins = (pkgshare/"sm-plugins")
        share_sm_plugins.mkpath
        resource("sm-plugin-brew").stage { share_sm_plugins.install "brew" }

        # Symlink to the brew sm-plugin from the shared folder
        # This allows users to remove the symlink if they don't want the sm-plugin
        # rather than deleting the whole file
        sm_plugins_dir = (etc/"tedge/sm-plugins")
        sm_plugins_dir.install_symlink share_sm_plugins/"brew"
        system "chmod", "555", "#{share_sm_plugins}/brew"
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
