class TedgeAgent < Formula
  desc "thin-edge.io tedge-agent service"
  homepage "https://thin-edge.io/"
  version "1.4.2"
  license "Apache-2.0"
  url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/tedge-agent-logs"
  sha256 "42dec6c7a1b2c53e7c29a4b73ddd7ccf3b2cbb916224d3fe57900a9320aae7bb"
  depends_on "tedge" => :optional
  depends_on "logrotate" => :recommended

  resource "tedge-agent-logs" do
    url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/tedge-agent-logs"
    sha256 "42dec6c7a1b2c53e7c29a4b73ddd7ccf3b2cbb916224d3fe57900a9320aae7bb"
  end

  def install
    # log helper
    resource("tedge-agent-logs").stage { bin.install "tedge-agent-logs" }

    # logrotate configuration to prevent large log files
    logrotate_dir = etc/"logrotate.d"
    logrotate_conf = logrotate_dir/"tedge-agent.conf"

    if logrotate_dir.exist?
      if !logrotate_conf.exist?
        logrotate_conf.write <<~EOS
          #{var}/log/tedge-agent.log {
            daily
            copytruncate
            rotate 3
            size 10M
            compress
          }
        EOS
      end
    end
  end

  service do
    name macos: "tedge-agent",
         linux: "tedge-agent"
    run ["#{HOMEBREW_PREFIX}/bin/tedge-agent"]
    environment_variables TEDGE_CONFIG_DIR: etc/"tedge"
    error_log_path var/"log/tedge-agent.log"
    keep_alive true
    restart_delay 5
  end
  def caveats
    <<~EOS
        View the service logs using:
          tedge-agent-logs
    EOS
  end
end
