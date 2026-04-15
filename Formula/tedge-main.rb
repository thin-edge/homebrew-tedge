# Code generated: DO NOT EDIT
class TedgeMain < Formula
    desc "IoT Device Management"
    homepage "https://thin-edge.io/"
    version "2.0.1-rc11+g02b3d3a"
    license "Apache-2.0"

    depends_on "mosquitto" => :optional
    depends_on "tedge-agent" => :recommended
    depends_on "tedge-mapper-cumulocity" => :recommended

    on_macos do
        on_arm do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-arm64/versions/2.0.1-rc11+g02b3d3a/tedge.tar.gz"
            sha256 "20d1bf55055afc211e56e07ff1d39b261bc78ed5ffbc810a44b35c56605eea8c"
        end
        on_intel do
            url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-macos-amd64/versions/2.0.1-rc11+g02b3d3a/tedge.tar.gz"
            sha256 "526f40db64deb51b51b5576a917f65ed31bd40af104059794036bf175f98f5c7"
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
        sha256 "b0c30901962bf5614e895576432db4987c444e28c5d437b55e220d7c2978e474"
    end

    # config plugins
    resource "config-plugins-file" do
        url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/config-plugins/file"
        sha256 "727053aacfafab21745e942af849412f1f5f217e60a45bdfd6c19624a2e6f39e"
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
        sha256 "ceaedca49540f156fc066864b30c7dedb7fd998fd8a73f4a6af75b3b4aa18abe"
    end

    def user
        Utils.safe_popen_read("id", "-un").chomp
    end

    def group
        Utils.safe_popen_read("id", "-gn").chomp
    end

    def install
        bin.install "tedge"
        bin.install_symlink bin/"tedge" => "tedge-flows-plugin"
        bin.install_symlink bin/"tedge" => "tedge-file-log-plugin"
        bin.install_symlink bin/"tedge" => "tedge-file-config-plugin"
        resource("brewctl").stage { bin.install "brewctl" }
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

        # system.toml settings
        # Always overwrite unless the user has opted out by adding "# managed-by: user" to the file.
        system_file = config_dir/"system.toml"
        if !system_file.exist? || !system_file.read.match?(/^# managed-by: user/)
            system_file.atomic_write <<~EOS
                # managed-by: homebrew-tedge
                # To prevent this file from being overwritten on upgrade, change the marker above to:
                #   # managed-by: user
                user = "#{user}"
                group = "#{group}"

                [system]
                reboot = ["brewctl", "reboot"]
                
                [init]
                name = "homebrew"
                is_available = ["brewctl", "services", "is_available"]
                restart = ["brewctl", "services", "restart", "{}"]
                stop =  ["brewctl", "services", "stop", "{}"]
                start =  ["brewctl", "services", "start", "{}"]
                enable =  ["brewctl", "services", "enable", "{}"]
                disable =  ["brewctl", "services", "disable", "{}"]
                is_active = ["brewctl", "services", "is-active", "{}"]
            EOS
        end

        # init should be run where the tedge binary is located so that the symlinks
        # are added to the global homebrew/bin directory
        # TODO: Check if the existing symlinks need to be removed
        system "#{bin}/tedge", "init", "--config-dir", "#{config_dir}", "--user=#{user}", "--group=#{group}"
        system "#{bin}/tedge", "--config-dir", "#{config_dir}", "config", "upgrade"
        with_env("PATH" => "#{bin}:#{ENV["PATH"]}") do
            unless quiet_system("#{bin}/tedge", "--config-dir", "#{config_dir}", "refresh-bridges")
                opoo "refresh-bridges failed (mosquitto may not be running yet). Run 'tedge reconnect c8y' once services are started."
            end
        end

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
        system "chmod", "-R", "755", share_log_plugins
        ohai "Installed log plugins to #{share_log_plugins}"
        system "#{bin}/tedge", "config", "--config-dir", "#{config_dir}", "set", "log.plugin_paths", share_log_plugins

        # config plugins
        share_config_plugins = (pkgshare/"config-plugins")
        share_config_plugins.mkpath
        resource("config-plugins-file").stage { share_config_plugins.install "file" }
        system "chmod", "-R", "755", share_config_plugins
        ohai "Installed log plugins to #{share_config_plugins}"
        system "#{bin}/tedge", "config", "--config-dir", "#{config_dir}", "set", "configuration.plugin_paths", share_config_plugins

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
        system "chmod", "-R", "755", share_diag_plugins
        system "#{bin}/tedge", "config", "--config-dir", "#{config_dir}", "set", "diag.plugin_paths", share_diag_plugins
        ohai "Installed diag plugins to #{share_diag_plugins}"

        # Symlink to the brew sm-plugin from the shared folder
        # This allows users to remove the symlink if they don't want the sm-plugin
        # rather than deleting the whole file
        sm_plugins_dir = (etc/"tedge/sm-plugins")
        sm_plugins_dir.install_symlink share_sm_plugins/"brew"
        system "chmod", "755", "#{share_sm_plugins}/brew"
        sm_plugins_dir = (etc/"tedge/sm-plugins")
        sm_plugins_dir.install_symlink share_sm_plugins/"brew"

        sm_plugins_dir.install_symlink bin/"tedge-flows-plugin" => "flow"

        # Install scripts
        shared_scripts = (pkgshare/"scripts")
        shared_scripts.mkpath
        resource("brewctl").stage { shared_scripts.install "brewctl" }
        system "chmod", "755", "#{shared_scripts}/brewctl"
        config_dir.install_symlink shared_scripts/"brewctl"
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

                DEVICE_ID="tedge_on_macos"
                tedge config set c8y.url "$C8Y_DOMAIN"
                ONE_TIME_PASSWORD=$(c8y deviceregistration register-ca --id "$DEVICE_ID" --select password -o csv)
                tedge cert download c8y --device-id "$DEVICE_ID" --one-time-password "$ONE_TIME_PASSWORD" --retry-every 5s
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
