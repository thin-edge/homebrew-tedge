class TedgeMapperCumulocity < Formula
  desc "thin-edge.io tedge-mapper-c8y service"
  homepage "https://thin-edge.io/"
  version "1.0.0"
  license "Apache-2.0"
  url "https://raw.githubusercontent.com/thin-edge/homebrew-tedge/main/Formula/tedge-mapper-cumulocity.rb"
  sha256 "648dab0315a52d721cee80466297d9e0a59006e78437e353d74481f9f789c9cd"
  depends_on "tedge" => :optional

  def install  
    # Create log helper
    log_script = bin/"tedge-mapper-c8y-logs"
    if !log_script.exist?
        log_script.write <<~EOS
            #!/bin/sh
            set -e
            tail -f "#{var}/log/tedge-mapper-c8y.log"
        EOS
    end
  end

  service do
    name macos: "tedge-mapper-c8y",
          linux: "tedge-mapper-c8y"
    run ["#{HOMEBREW_PREFIX}/bin/tedge-mapper", "--config-dir", etc/"tedge", "c8y"]
    error_log_path var/"log/tedge-mapper-c8y.log"
    keep_alive false
  end
  def caveats
    <<~EOS
        tedge-mapper-c8y service

        View the logs using:
          tedge-mapper-c8y-logs
    EOS
  end
end
