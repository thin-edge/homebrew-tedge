# Code generated: DO NOT EDIT
class TedgeMain < Formula
    desc "IoT Device Management"
    homepage "https://thin-edge.io/"
    version "1.7.2-rc236+gd4b06b6"
    license "Apache-2.0"

    depends_on "mosquitto" => :optional
    depends_on "tedge-agent" => :recommended
    depends_on "tedge-mapper-cumulocity" => :recommended

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-arm64/versions/1.7.2-rc236+gd4b06b6/tedge.tar.gz"
            sha256 "b5ac86bd9c8fe9f8b5617d2ec086d9d96cd2663f30ae234f0d238607567f22c5"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-amd64/versions/1.7.2-rc236+gd4b06b6/tedge.tar.gz"
            sha256 "12236f65f385472d5c6cd750f02049d84243cd23b1ffd24052a81ee68e4281dd"
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

    # log plugins
    resource "log-plugins-file" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/log-plugins/file"
        sha256 "e70106ce3b197a18d32db83493fe51fee05ec78da1374fc4c37aceaa65af65b3"
    end

    # diag plugins
    resource "diag-plugins-01_tedge.sh" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/diag-plugins/01_tedge.sh"
        sha256 "e38abbc7b616a1c2c75a0fe9a9834e983cb4cc3d4700ecdf8387e6492e7d03a2"
    end
    resource "diag-plugins-02_os.sh" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/diag-plugins/02_os.sh"
        sha256 "e18d510f69119208fbfba86a95386c4127deab4b0e6d61ce280cba2e2f4849aa"
    end
    resource "diag-plugins-03_mqtt.sh" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/diag-plugins/03_mqtt.sh"
        sha256 "e2983078fce45ba07572cb33ead0c3f3398d2507690d825563409bbc86401939"
    end
    resource "diag-plugins-04_workflow.sh" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/diag-plugins/04_workflow.sh"
        sha256 "d2db9759ec597fccc31dbcf4a431b8770f640543bfd409dbfb93781ee2e0d9d6"
    end
    resource "diag-plugins-05_entities.sh" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/diag-plugins/05_entities.sh"
        sha256 "286b4dabeaae417dc0cf0dbe9bacb589df100087fd3995304a57e1db04b89496"
    end
    resource "diag-plugins-06_internal.sh" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/diag-plugins/06_internal.sh"
        sha256 "772646a6ec6efa89a1ffdbd22c841bf4cf1862d4dd70f4399ce67d50bad03e21"
    end
    resource "diag-plugins-07_mosquitto.sh" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/diag-plugins/07_mosquitto.sh"
        sha256 "ab17534fa6c12ad05d564865b1d6b1a8d642113cf914033cb361f2fd49a2bff8"
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

        # log plugins
        share_log_plugins = (pkgshare/"log-plugins")
        share_log_plugins.mkpath
        resource("log-plugins-file").stage { share_log_plugins.install "file" }
        system "chmod", "-R", "555", share_log_plugins
        ohai "Installed log plugins to #{share_log_plugins}"
        system "#{HOMEBREW_PREFIX}/bin/tedge", "config", "--config-dir", "#{config_dir}", "set", "log.plugin_paths", share_log_plugins

        # diag plugins
        share_diag_plugins = (pkgshare/"diag-plugins")
        share_diag_plugins.mkpath
        resource("diag-plugins-01_tedge.sh").stage { share_diag_plugins.install "01_tedge.sh" }
        resource("diag-plugins-02_os.sh").stage { share_diag_plugins.install "02_os.sh" }
        resource("diag-plugins-03_mqtt.sh").stage { share_diag_plugins.install "03_mqtt.sh" }
        resource("diag-plugins-04_workflow.sh").stage { share_diag_plugins.install "04_workflow.sh" }
        resource("diag-plugins-05_entities.sh").stage { share_diag_plugins.install "05_entities.sh" }
        resource("diag-plugins-06_internal.sh").stage { share_diag_plugins.install "06_internal.sh" }
        resource("diag-plugins-07_mosquitto.sh").stage { share_diag_plugins.install "07_mosquitto.sh" }
        system "chmod", "-R", "555", share_diag_plugins
        system "#{HOMEBREW_PREFIX}/bin/tedge", "config", "--config-dir", "#{config_dir}", "set", "diag.plugin_paths", share_diag_plugins
        ohai "Installed diag plugins to #{share_diag_plugins}"

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
