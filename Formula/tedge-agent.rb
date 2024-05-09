class TedgeAgent < Formula
  desc "thin-edge.io tedge-agent service"
  homepage "https://thin-edge.io/"
  version "1.0.0"
  license "Apache-2.0"
  url "https://thin-edge.io/"
  depends_on "tedge" => :optional

  def install
    # Create log helper
    log_script = bin/"tedge-agent-logs"
    if !log_script.exist?
        log_script.write <<~EOS
            #!/bin/sh
            set -e
            tail -f "#{var}/log/tedge-agent.log"
        EOS
    end
  end

  service do
    name macos: "tedge-agent",
         linux: "tedge-agent"
    run ["#{HOMEBREW_PREFIX}/bin/tedge-agent", "--config-dir", etc/"tedge"]
    error_log_path var/"log/tedge-agent.log"
    keep_alive false
  end
  def caveats
    <<~EOS
        tedge-agent service

        View the logs using:
          tedge-agent-logs
    EOS
  end
end
