class TedgeMapperCumulocity < Formula
  desc "thin-edge.io tedge-mapper-c8y service"
  homepage "https://thin-edge.io/"
  version "1.4.2"
  license "Apache-2.0"
  url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/tedge-mapper-c8y-logs"
  sha256 "f04d2c22735a885904f4bd29283d98e253e5b2186300f212364b3039098bcb55"
  depends_on "tedge" => :optional
  depends_on "logrotate" => :recommended

  resource "tedge-mapper-c8y-logs" do
    url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/extras/tedge-mapper-c8y-logs"
    sha256 "f04d2c22735a885904f4bd29283d98e253e5b2186300f212364b3039098bcb55"
  end

  def install  
    # log helper
    resource("tedge-mapper-c8y-logs").stage { bin.install "tedge-mapper-c8y-logs" }

    # logrotate configuration to prevent large log files
    logrotate_dir = etc/"logrotate.d"
    logrotate_conf = logrotate_dir/"tedge-mapper-c8y.conf"

    if logrotate_dir.exist?
      if !logrotate_conf.exist?
        logrotate_conf.write <<~EOS
          #{var}/log/tedge-mapper-c8y.log {
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
    name macos: "tedge-mapper-cumulocity",
         linux: "tedge-mapper-cumulocity"
    run ["#{HOMEBREW_PREFIX}/bin/tedge-mapper", "c8y"]
    environment_variables TEDGE_CONFIG_DIR: etc/"tedge"
    error_log_path var/"log/tedge-mapper-c8y.log"
    keep_alive true
    restart_delay 5
  end
  def caveats
    <<~EOS
        Note: Due to a homebrew limitation, the c8y mapper service is called "tedge-mapper-cumulocity"
        instead of the expected "tedge-mapper-c8y". The brewctl script will handle the service alias
        for you, e.g. "brewctl start tedge-mapper-c8y" will actually start the homebrew "tedge-mapper-cumulocity" service

        View the service logs using:
          tedge-mapper-c8y-logs
    EOS
  end
end
