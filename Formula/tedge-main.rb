# Code generated: DO NOT EDIT
class TedgeMain < Formula
    desc "IoT Device Management"
    homepage "https://thin-edge.io/"
    version "1.4.3-rc255+g7c0b549"
    license "Apache-2.0"

    depends_on "mosquitto" => :optional
    depends_on "tedge-agent" => :recommended
    depends_on "tedge-mapper-cumulocity" => :recommended

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-arm64/versions/1.4.3-rc255+g7c0b549/tedge.tar.gz"
            sha256 "71c82b98a590d4734ebf3220033805701c359e5a3657f37ae9e2e89ac040b6a2"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-amd64/versions/1.4.3-rc255+g7c0b549/tedge.tar.gz"
            sha256 "9a6393495cb81dc043d78d65264dcbfb6b664960d902682d52b66b5d9284878d"
        end
    end

    resource "sm-plugin-brew" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/sm-plugins/brew"
        sha256 "f6c42a2e1e205af6a3f615e50fd07c283bab94d4bee7912014b7c2a92e42e35c"
    end

    resource "brewctl" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/brewctl"
        sha256 "78d48cacf66b98a8335c5b4834a3e7507bef4b16d230cb728a839dd5bcca6b8a"
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

                [c8y]
                root_cert_path = "#{HOMEBREW_PREFIX}/share/ca-certificates/cacert.pem"

                [az]
                root_cert_path = "#{HOMEBREW_PREFIX}/share/ca-certificates/cacert.pem"

                [aws]
                root_cert_path = "#{HOMEBREW_PREFIX}/share/ca-certificates/cacert.pem"
                
                [logs]
                path = "#{var}/log/tedge"
                
                [data]
                path = "#{var}/tedge"
                
                [http]
                bind.port=8008
                client.port=8008
            EOS
        end

        # init should be run where the tedge binary is located so that the symlinks
        # are added to the global homebrew/bin directory
        # TODO: Check if the existing symlinks need to be removed
        system "#{HOMEBREW_PREFIX}/bin/tedge", "init", "--config-dir", "#{config_dir}", "--user=#{user}", "--group=#{group}"

        # FIXME: Uncomment once https://github.com/thin-edge/thin-edge.io/issues/2886 is resolved
        # system "#{bin}/c8y-remote-access-plugin", "--config-dir", "#{config_dir}", "--init"
        # Workaround: create the file manually
        remoteAccessHandlerFile = config_dir/"operations/c8y/c8y_RemoteAccessConnect"
        rm_f remoteAccessHandlerFile
        remoteAccessHandlerFile.write <<~EOS
            [exec]
            command = "#{HOMEBREW_PREFIX}/bin/c8y-remote-access-plugin"
            topic = "c8y/s/ds"
            on_message = "530"
        EOS

        # Add mosquitto configuration to persist across service restarts (e.g. db persistence)
        # TODO: mosquitto can't load a file it saved itself due to the permissions not being correctly set (e.g. group is not set to "staff")
        #   Warning: File /opt/homebrew/var/mosquitto/mosquitto.db group is not staff. Future versions will refuse to load this file.
        custom_mosquitto_config_file = (etc/"tedge/mosquitto-conf/tedge-persistence.conf")
        if !custom_mosquitto_config_file.exist?
            custom_mosquitto_config_file.write <<~EOS
                persistence true
                persistence_location #{HOMEBREW_PREFIX}/var/mosquitto/
                autosave_interval 10
                autosave_on_changes true
            EOS
        end

        # Ensure location of the mosquitto persistence file has the correct permissions
        # otherwise mosquitto will ignore the file
        (var/"mosquitto").mkpath
        system "chown", "-R", "#{user}:#{group}", "#{var}/mosquitto"

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
        sm_plugins_dir = (etc/"tedge/sm-plugins")
        sm_plugins_dir.install_symlink share_sm_plugins/"brew"

        # Install scripts
        shared_scripts = (pkgshare/"scripts")
        shared_scripts.mkpath
        resource("brewctl").stage { shared_scripts.install "brewctl" }
        system "chmod", "555", "#{shared_scripts}/brewctl"
        config_dir.install_symlink shared_scripts/"brewctl"

        # system.toml settings
        system_file = config_dir/"system.toml"
        if !system_file.exist?
            system_file.write <<~EOS
                [system]
                reboot = ["#{config_dir}/brewctl", "reboot"]
                
                [init]
                name = "homebrew"
                is_available = ["#{config_dir}/brewctl", "services", "is_available"]
                restart = ["#{config_dir}/brewctl", "services", "restart", "{}"]
                stop =  ["#{config_dir}/brewctl", "services", "stop", "{}"]
                start =  ["#{config_dir}/brewctl", "services", "start", "{}"]
                enable =  ["#{config_dir}/brewctl", "services", "enable", "{}"]
                disable =  ["#{config_dir}/brewctl", "services", "disable", "{}"]
                is_active = ["#{config_dir}/brewctl", "services", "is-active", "{}"]
            EOS
        end

    end

    def caveats
        <<~EOS
            thin-edge.io has been installed with a default configuration file.
            You can make changes to the configuration by editing:
                #{etc}/tedge/tedge.toml

            You need to manually edit the mosquitto configuration to add the following line:
                sh -c 'echo include_dir #{etc}/tedge/mosquitto-conf >> "#{etc}/mosquitto/mosquitto.conf"'

            Configure your zsh profile then reload it
                sh -c 'echo export TEDGE_CONFIG_DIR=\"#{etc}/tedge\"' >> "$HOME/.zshrc"
                sh -c 'echo "source <(tedge completions zsh)"' >> "$HOME/.zshrc"
                
                . "$HOME/.zshrc"

            Onboarding instructions:

                tedge cert create --device-id "tedge_on_macos"
                tedge config set c8y.url "$C8Y_DOMAIN"
                tedge cert upload c8y --user "$C8Y_USER"
                tedge connect c8y


            To view logs, run:

                tedge-mapper-c8y-logs
                tedge-agent-logs
            
            
            Service control:

                brew services restart tedge-agent
                brew services restart tedge-mapper-cumulocity

            Activate tedge-main (and disable tedge):

                brew unlink tedge; brew link tedge-main

            Deactivate tedge-main (and enable tedge):

                brew unlink tedge-main; brew link tedge
        EOS
    end

    test do
        quiet_system "#{bin}/tedge", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
        quiet_system "#{bin}/tedge-agent", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
        quiet_system "#{bin}/tedge-mapper", "--help"
        assert_equal 0, $CHILD_STATUS.exitstatus
    end
end
